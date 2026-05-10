use bitcoin::Amount;
use tracing::{error, info};

use super::AppCore;
use crate::state::*;

impl AppCore {
    /// Parse a recipient string and determine its type.
    pub(crate) fn handle_parse_recipient(&mut self, input: String) {
        let input = input.trim().to_string();
        let normalized = input.to_lowercase();
        let max_sendable_sats = self
            .state
            .balance
            .as_ref()
            .map(|b| b.offchain_total_sats)
            .unwrap_or(0);

        // Try Ark address first
        if let Ok(addr) = ark_core::ArkAddress::decode(&input) {
            self.state.send_flow = Some(SendFlowState {
                recipient: input,
                recipient_type: RecipientType::ArkAddress,
                amount_sats: None,
                estimated_fee_sats: Some(0), // Ark sends are free
                max_sendable_sats,
                is_sending: false,
                error: None,
                confirmation: None,
            });
            let _ = addr; // used for validation
            self.emit_state();
            return;
        }

        // Try Bitcoin address
        if input.starts_with("tb1")
            || input.starts_with("bc1")
            || input.starts_with("1")
            || input.starts_with("3")
            || input.starts_with("2")
            || input.starts_with("m")
            || input.starts_with("n")
        {
            self.state.send_flow = Some(SendFlowState {
                recipient: input,
                recipient_type: RecipientType::BitcoinAddress,
                amount_sats: None,
                estimated_fee_sats: None,
                max_sendable_sats,
                is_sending: false,
                error: None,
                confirmation: None,
            });
            self.emit_state();
            return;
        }

        // Try Lightning invoice
        if normalized.starts_with("ln") {
            let invoice = match normalized.parse::<ark_client::lightning_invoice::Bolt11Invoice>() {
                Ok(invoice) => invoice,
                Err(e) => {
                    self.state.send_flow = Some(SendFlowState {
                        recipient: input,
                        recipient_type: RecipientType::LightningInvoice,
                        amount_sats: None,
                        estimated_fee_sats: None,
                        max_sendable_sats,
                        is_sending: false,
                        error: Some(format!("Invalid Lightning invoice: {e}")),
                        confirmation: None,
                    });
                    self.emit_state();
                    return;
                }
            };

            let amount_sats = invoice
                .amount_milli_satoshis()
                .map(|msats| msats.div_ceil(1000));
            let error = if amount_sats.is_none() {
                Some("Amountless Lightning invoices are not supported yet. Use a fixed-amount invoice.".to_string())
            } else {
                None
            };
            let estimated_fee_sats =
                amount_sats.and_then(|sats| self.estimate_submarine_fee_sats(sats));
            let confirmation = amount_sats.map(|amount| SendConfirmation {
                recipient_display: "Lightning invoice".to_string(),
                amount_sats: amount,
                fee_sats: estimated_fee_sats.unwrap_or(0),
                total_sats: amount + estimated_fee_sats.unwrap_or(0),
                is_swap: true,
            });

            self.state.send_flow = Some(SendFlowState {
                recipient: normalized,
                recipient_type: RecipientType::LightningInvoice,
                amount_sats,
                estimated_fee_sats,
                max_sendable_sats,
                is_sending: false,
                error,
                confirmation,
            });
            self.emit_state();
            return;
        }

        // Try ArkNote
        if input.starts_with("arknote") || input.starts_with("ark1") {
            self.state.send_flow = Some(SendFlowState {
                recipient: input,
                recipient_type: RecipientType::ArkNote,
                amount_sats: None,
                estimated_fee_sats: None,
                max_sendable_sats: 0,
                is_sending: false,
                error: None,
                confirmation: None,
            });
            self.emit_state();
            return;
        }

        // Unknown
        self.state.send_flow = Some(SendFlowState {
            recipient: input,
            recipient_type: RecipientType::Unknown,
            amount_sats: None,
            estimated_fee_sats: None,
            max_sendable_sats: 0,
            is_sending: false,
            error: Some("Unrecognized address format".to_string()),
            confirmation: None,
        });
        self.emit_state();
    }

    /// Set the send amount.
    pub(crate) fn handle_set_send_amount(&mut self, sats: u64) {
        if let Some(flow) = &mut self.state.send_flow {
            flow.amount_sats = Some(sats);
        }
        self.update_send_confirmation();
        self.emit_state();
    }

    /// Confirm and execute the send.
    pub(crate) fn handle_confirm_send(&mut self) {
        if self.ark_client.is_none() {
            self.show_toast("Wallet not connected", true);
            return;
        }

        let flow = match &self.state.send_flow {
            Some(f) => f.clone(),
            None => {
                self.show_toast("No send in progress", true);
                return;
            }
        };

        let amount_sats = match flow.amount_sats {
            Some(a) => a,
            None => {
                self.show_toast("No amount set", true);
                return;
            }
        };

        match flow.recipient_type {
            RecipientType::ArkAddress => {
                self.send_to_ark_address(&flow.recipient, amount_sats);
            }
            RecipientType::LightningInvoice => {
                if let Some(error) = flow.error {
                    self.show_toast(&error, true);
                    return;
                }
                self.handle_submarine_swap(flow.recipient.clone());
            }
            RecipientType::BitcoinAddress => {
                // On-chain sends go through collaborative redeem
                self.send_onchain(&flow.recipient, amount_sats);
            }
            _ => {
                self.show_toast("Cannot send to this recipient type", true);
            }
        }
    }

    /// Send VTXOs to an Ark address.
    fn send_to_ark_address(&mut self, recipient: &str, amount_sats: u64) {
        let addr = match ark_core::ArkAddress::decode(recipient) {
            Ok(a) => a,
            Err(e) => {
                self.show_toast(&format!("Invalid Ark address: {e}"), true);
                return;
            }
        };

        if let Some(flow) = &mut self.state.send_flow {
            flow.is_sending = true;
        }
        self.emit_state();

        let client = self.ark_client.as_ref().unwrap();
        let result = self
            .rt
            .block_on(client.send_vtxo(addr, Amount::from_sat(amount_sats)));

        match result {
            Ok(txid) => {
                info!("sent {} sats to ark address, txid: {}", amount_sats, txid);
                if let Some(flow) = &mut self.state.send_flow {
                    flow.is_sending = false;
                }
                self.state.router.screen_stack.push(Screen::SendSuccess);
                self.show_toast(&format!("Sent {} sats! TX: {}", amount_sats, txid), false);
            }
            Err(e) => {
                error!("send failed: {e}");
                if let Some(flow) = &mut self.state.send_flow {
                    flow.is_sending = false;
                    flow.error = Some(format!("{e}"));
                }
                self.show_toast(&format!("Send failed: {e}"), true);
            }
        }
    }

    /// Send to an on-chain Bitcoin address via collaborative redeem.
    fn send_onchain(&mut self, recipient: &str, amount_sats: u64) {
        let addr = match recipient.parse::<bitcoin::Address<bitcoin::address::NetworkUnchecked>>() {
            Ok(a) => a.assume_checked(),
            Err(e) => {
                self.show_toast(&format!("Invalid BTC address: {e}"), true);
                return;
            }
        };

        if let Some(flow) = &mut self.state.send_flow {
            flow.is_sending = true;
        }
        self.emit_state();

        let mut rng = rand::thread_rng();
        let client = self.ark_client.as_ref().unwrap();
        let result = self.rt.block_on(client.collaborative_redeem(
            &mut rng,
            addr,
            Amount::from_sat(amount_sats),
        ));

        match result {
            Ok(txid) => {
                info!("collaborative redeem sent, txid: {:?}", txid);
                if let Some(flow) = &mut self.state.send_flow {
                    flow.is_sending = false;
                }
                self.state.router.screen_stack.push(Screen::SendSuccess);
                self.show_toast(&format!("Sent {} sats on-chain!", amount_sats), false);
            }
            Err(e) => {
                error!("on-chain send failed: {e}");
                if let Some(flow) = &mut self.state.send_flow {
                    flow.is_sending = false;
                    flow.error = Some(format!("{e}"));
                }
                self.show_toast(&format!("Send failed: {e}"), true);
            }
        }
    }

    /// Cancel the current send flow.
    pub(crate) fn handle_cancel_send(&mut self) {
        self.state.send_flow = None;
        self.emit_state();
    }

    fn update_send_confirmation(&mut self) {
        let Some(flow) = &mut self.state.send_flow else {
            return;
        };
        let Some(amount) = flow.amount_sats else {
            flow.confirmation = None;
            return;
        };

        let (recipient_display, fee_sats, is_swap) = match flow.recipient_type {
            RecipientType::ArkAddress => ("Arkade address".to_string(), 0, false),
            RecipientType::LightningInvoice => (
                "Lightning invoice".to_string(),
                flow.estimated_fee_sats.unwrap_or(0),
                true,
            ),
            RecipientType::BitcoinAddress => (
                "bitcoin address".to_string(),
                flow.estimated_fee_sats.unwrap_or(0),
                false,
            ),
            _ => {
                flow.confirmation = None;
                return;
            }
        };

        flow.confirmation = Some(SendConfirmation {
            recipient_display,
            amount_sats: amount,
            fee_sats,
            total_sats: amount + fee_sats,
            is_swap,
        });
    }

    fn estimate_submarine_fee_sats(&self, amount_sats: u64) -> Option<u64> {
        let percent = self.state.boltz.as_ref()?.submarine_fee_percent?;
        Some(((amount_sats as f64 * percent) / 100.0).ceil() as u64)
    }
}

#[cfg(test)]
mod tests {
    use std::sync::{Arc, RwLock};

    use super::*;
    use crate::updates::CoreMsg;

    const FIXED_BOLT11_INVOICE: &str = "lnbc2500u1pvjluezsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygspp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpu9qrsgquk0rl77nj30yxdy8j9vdx85fkpmdla2087ne0xh8nhedh8w27kyke0lp53ut353s06fv3qfegext0eh0ymjpf39tuven09sam30g4vgpfna3rh";
    const AMOUNTLESS_BOLT11_INVOICE: &str = "lnbc1pvjluezsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygspp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdpl2pkx2ctnv5sxxmmwwd5kgetjypeh2ursdae8g6twvus8g6rfwvs8qun0dfjkxaq9qrsgq357wnc5r2ueh7ck6q93dj32dlqnls087fxdwk8qakdyafkq3yap9us6v52vjjsrvywa6rt52cm9r9zqt8r2t7mlcwspyetp5h2tztugp9lfyql";

    fn test_core() -> AppCore {
        let (update_tx, _update_rx) = flume::unbounded();
        let (core_tx, _core_rx) = flume::unbounded::<CoreMsg>();
        let shared_state = Arc::new(RwLock::new(AppState::default()));
        let data_dir = std::env::temp_dir()
            .join(format!("arkade-native-test-{}", std::process::id()))
            .to_string_lossy()
            .to_string();

        AppCore::new(
            update_tx,
            core_tx,
            shared_state,
            data_dir,
            "regtest".to_string(),
        )
    }

    #[test]
    fn parses_fixed_lightning_invoice_as_boltz_swap() {
        let mut core = test_core();
        core.state.balance = Some(BalanceState {
            offchain_total_sats: 300_000,
            ..Default::default()
        });
        core.state.boltz = Some(BoltzState {
            is_connected: true,
            submarine_fee_percent: Some(0.5),
            ..Default::default()
        });

        core.handle_parse_recipient(FIXED_BOLT11_INVOICE.to_string());

        let flow = core.state.send_flow.expect("send flow should be populated");
        assert_eq!(flow.recipient_type, RecipientType::LightningInvoice);
        assert_eq!(flow.recipient, FIXED_BOLT11_INVOICE);
        assert_eq!(flow.amount_sats, Some(250_000));
        assert_eq!(flow.estimated_fee_sats, Some(1_250));
        assert_eq!(flow.max_sendable_sats, 300_000);
        assert!(flow.error.is_none());

        let confirmation = flow.confirmation.expect("confirmation should be ready");
        assert_eq!(confirmation.recipient_display, "Lightning invoice");
        assert_eq!(confirmation.amount_sats, 250_000);
        assert_eq!(confirmation.fee_sats, 1_250);
        assert_eq!(confirmation.total_sats, 251_250);
        assert!(confirmation.is_swap);
    }

    #[test]
    fn rejects_amountless_lightning_invoice_before_confirm() {
        let mut core = test_core();

        core.handle_parse_recipient(AMOUNTLESS_BOLT11_INVOICE.to_string());

        let flow = core.state.send_flow.expect("send flow should be populated");
        assert_eq!(flow.recipient_type, RecipientType::LightningInvoice);
        assert_eq!(flow.amount_sats, None);
        assert!(flow.confirmation.is_none());
        assert_eq!(
            flow.error.as_deref(),
            Some("Amountless Lightning invoices are not supported yet. Use a fixed-amount invoice.")
        );
    }
}
