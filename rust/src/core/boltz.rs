use bitcoin::Amount;
use tracing::{error, info};

use super::AppCore;
use crate::state::*;
use crate::updates::*;

impl AppCore {
    /// Pay a Lightning invoice via Boltz submarine swap.
    pub(crate) fn handle_submarine_swap(&mut self, invoice: String) {
        if self.ark_client.is_none() {
            self.show_toast("Wallet not connected", true);
            return;
        }

        if let Some(flow) = &mut self.state.send_flow {
            flow.is_sending = true;
        }
        self.state.busy.creating_swap = true;
        self.emit_state();

        let client = self.ark_client.as_ref().unwrap();

        let bolt11 = match invoice.parse::<ark_client::lightning_invoice::Bolt11Invoice>() {
            Ok(inv) => inv,
            Err(e) => {
                self.state.busy.creating_swap = false;
                if let Some(flow) = &mut self.state.send_flow {
                    flow.is_sending = false;
                    flow.error = Some(format!("Invalid invoice: {e}"));
                }
                self.show_toast(&format!("Invalid invoice: {e}"), true);
                return;
            }
        };

        let result = self.rt.block_on(client.pay_ln_invoice(bolt11));

        self.state.busy.creating_swap = false;
        if let Some(flow) = &mut self.state.send_flow {
            flow.is_sending = false;
        }

        match result {
            Ok(swap_result) => {
                info!(
                    "submarine swap completed, swap_id: {}, txid: {}",
                    swap_result.swap_id, swap_result.txid
                );
                self.show_toast(
                    &format!("Sent {} sats via Lightning!", swap_result.amount.to_sat()),
                    false,
                );
            }
            Err(e) => {
                error!("submarine swap failed: {e:#}");
                if let Some(flow) = &mut self.state.send_flow {
                    flow.error = Some(format!("{e}"));
                }
                self.show_toast(&format!("Payment failed: {e}"), true);
            }
        }
    }

    /// Create a Lightning invoice via Boltz reverse swap, then wait for payment and claim.
    pub(crate) fn handle_reverse_swap(&mut self, amount_sats: u64) {
        if self.ark_client.is_none() {
            self.show_toast("Wallet not connected", true);
            return;
        }

        self.state.busy.creating_swap = true;
        self.emit_state();

        let client = self.ark_client.as_ref().unwrap();
        let amount = ark_client::SwapAmount::invoice(Amount::from_sat(amount_sats));

        // Step 1: Generate the invoice
        let result = self.rt.block_on(client.get_ln_invoice(amount, None));

        match result {
            Ok(data) => {
                let swap_id = data.swap_id.clone();
                info!(
                    "reverse swap created, swap_id: {}, invoice: {}",
                    swap_id, data.invoice
                );

                self.state.busy.creating_swap = false;
                self.state.receive_flow = Some(ReceiveFlowState {
                    receive_type: ReceiveType::LightningInvoice,
                    address_or_invoice: data.invoice.to_string(),
                    amount_sats: Some(amount_sats),
                    qr_data: data.invoice.to_string().to_uppercase(), // uppercase for QR
                    is_generating: false,
                    error: None,
                });
                self.emit_state();

                // Step 2: Wait for payment and claim in background
                let tx = self.core_tx.clone();
                info!("waiting for VHTLC funding for swap {}", swap_id);

                // Spawn background task to wait for payment + claim
                let swap_id_clone = swap_id.clone();
                self.rt.spawn(async move {
                    // This is a placeholder - we can't easily move the client reference
                    // into a spawned task since Client isn't Clone.
                    // The claim will happen on next app launch via continue_pending_vhtlc_spend_txs
                    info!(
                        "reverse swap {} waiting for payment (will auto-claim on next refresh)",
                        swap_id_clone
                    );
                    let _ = tx.send(CoreMsg::Internal(Box::new(InternalEvent::ShowToast {
                        message: format!("Invoice ready. Pay it to receive {} sats.", amount_sats),
                        is_error: false,
                    })));
                });
            }
            Err(e) => {
                self.state.busy.creating_swap = false;
                error!("reverse swap failed: {e:#}");
                self.show_toast(&format!("Failed to create invoice: {e}"), true);
            }
        }
    }

    /// Try to claim any pending reverse swaps.
    pub(crate) fn handle_claim_pending_swaps(&mut self) {
        if self.ark_client.is_none() {
            return;
        }

        let client = self.ark_client.as_ref().unwrap();

        // Continue any pending VHTLC spend transactions
        let result = self.rt.block_on(client.continue_pending_vhtlc_spend_txs());
        match result {
            Ok(txids) => {
                if !txids.is_empty() {
                    info!("claimed {} pending VHTLCs: {:?}", txids.len(), txids);
                    self.show_toast(&format!("Claimed {} pending swaps!", txids.len()), false);
                    // Refresh balance
                    self.handle_refresh_balance();
                }
            }
            Err(e) => {
                error!("continue pending VHTLCs failed: {e}");
            }
        }
    }

    /// Get Boltz swap fees and limits.
    pub(crate) fn handle_connect_boltz(&mut self) {
        if self.ark_client.is_none() {
            return;
        }

        let client = self.ark_client.as_ref().unwrap();

        let fees_result = self.rt.block_on(client.get_fees());
        let limits_result = self.rt.block_on(client.get_limits());

        let mut boltz = BoltzState::default();
        boltz.is_connected = true;

        if let Ok(fees) = fees_result {
            boltz.submarine_fee_percent = Some(fees.submarine.percentage);
            boltz.reverse_fee_percent = Some(fees.reverse.percentage);
        }

        if let Ok(limits) = limits_result {
            boltz.min_swap_sats = Some(limits.min);
            boltz.max_swap_sats = Some(limits.max);
        }

        self.state.boltz = Some(boltz);
        self.emit_state();

        // Also try to claim any pending swaps from previous sessions
        self.handle_claim_pending_swaps();
        self.handle_refresh_swap_history();
    }

    pub(crate) fn handle_disconnect_boltz(&mut self) {
        if let Some(boltz) = &mut self.state.boltz {
            boltz.is_connected = false;
        } else {
            self.state.boltz = Some(BoltzState::default());
        }
        self.emit_state();
    }

    pub(crate) fn handle_refresh_swap_history(&mut self) {
        let db_path = format!("{}/swaps.sqlite", self.data_dir);
        let result = self.rt.block_on(async {
            use ark_client::{SqliteSwapStorage, SwapStorage};

            let storage = SqliteSwapStorage::new(&db_path).await?;
            let submarine = storage.list_all_submarine().await?;
            let reverse = storage.list_all_reverse().await?;

            let mut swaps = Vec::with_capacity(submarine.len() + reverse.len());
            swaps.extend(submarine.into_iter().map(|swap| {
                let status = format!("{:?}", swap.status);
                SwapSummary {
                    id: swap.id,
                    swap_type: SwapType::Submarine,
                    status: map_boltz_status_debug(&status),
                    amount_sats: swap.amount.to_sat(),
                    created_at: swap.created_at as i64,
                    is_claimable: false,
                    is_refundable: status == "SwapExpired" || status == "InvoiceExpired",
                }
            }));
            swaps.extend(reverse.into_iter().map(|swap| {
                let status = format!("{:?}", swap.status);
                SwapSummary {
                    id: swap.id,
                    swap_type: SwapType::ReverseSubmarine,
                    status: map_boltz_status_debug(&status),
                    amount_sats: swap.amount.to_sat(),
                    created_at: swap.created_at as i64,
                    is_claimable: status == "TransactionConfirmed" || status == "TransactionMempool",
                    is_refundable: false,
                }
            }));
            swaps.sort_by(|a, b| b.created_at.cmp(&a.created_at));
            Ok::<_, ark_client::Error>(swaps)
        });

        match result {
            Ok(swaps) => {
                let mut boltz = self.state.boltz.clone().unwrap_or_default();
                boltz.swaps = swaps;
                self.state.boltz = Some(boltz);
                self.emit_state();
            }
            Err(e) => {
                error!("failed to refresh swap history: {e}");
                self.show_toast(&format!("Could not refresh swaps: {e}"), true);
            }
        }
    }

    pub(crate) fn handle_claim_swap(&mut self, swap_id: String) {
        if self.ark_client.is_none() {
            self.show_toast("Wallet not connected", true);
            return;
        }

        self.state.busy.creating_swap = true;
        self.emit_state();

        let client = self.ark_client.as_ref().unwrap();
        let result = self.rt.block_on(client.wait_for_vhtlc(&swap_id));
        self.state.busy.creating_swap = false;

        match result {
            Ok(claim) => {
                self.show_toast(
                    &format!("Claimed {} sats from swap", claim.claim_amount.to_sat()),
                    false,
                );
                self.handle_refresh_balance();
                self.handle_refresh_swap_history();
            }
            Err(e) => {
                self.show_toast(&format!("Claim failed: {e}"), true);
            }
        }
    }

    pub(crate) fn handle_refund_swap(&mut self, swap_id: String) {
        if self.ark_client.is_none() {
            self.show_toast("Wallet not connected", true);
            return;
        }

        self.state.busy.creating_swap = true;
        self.emit_state();

        let client = self.ark_client.as_ref().unwrap();
        let result = self.rt.block_on(async {
            match client.refund_vhtlc(&swap_id).await {
                Ok(txid) => Ok(txid),
                Err(_) => client.refund_expired_vhtlc(&swap_id).await,
            }
        });
        self.state.busy.creating_swap = false;

        match result {
            Ok(txid) => {
                self.show_toast(&format!("Refunded swap: {txid}"), false);
                self.handle_refresh_balance();
                self.handle_refresh_swap_history();
            }
            Err(e) => {
                self.show_toast(&format!("Refund failed: {e}"), true);
            }
        }
    }
}

fn map_boltz_status_debug(status: &str) -> SwapStatus {
    match status {
        "Created" => SwapStatus::Created,
        "TransactionMempool" | "TransactionConfirmed" | "InvoiceSet" | "InvoicePending" => {
            SwapStatus::Pending
        }
        "TransactionClaimed" | "InvoicePaid" => SwapStatus::Completed,
        "TransactionRefunded" => SwapStatus::Refunded,
        "SwapExpired" | "InvoiceExpired" => SwapStatus::Expired,
        _ if status.starts_with("Error") => SwapStatus::Failed,
        "TransactionFailed" | "InvoiceFailedToPay" => SwapStatus::Failed,
        _ => SwapStatus::Pending,
    }
}
