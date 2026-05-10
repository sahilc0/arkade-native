use bitcoin::Amount;
use tracing::{error, info};

use super::AppCore;
use crate::state::*;

impl AppCore {
    /// Parse a recipient string and determine its type.
    pub(crate) fn handle_parse_recipient(&mut self, input: String) {
        // Try Ark address first
        if let Ok(addr) = ark_core::ArkAddress::decode(&input) {
            self.state.send_flow = Some(SendFlowState {
                recipient: input,
                recipient_type: RecipientType::ArkAddress,
                amount_sats: None,
                estimated_fee_sats: Some(0), // Ark sends are free
                max_sendable_sats: self
                    .state
                    .balance
                    .as_ref()
                    .map(|b| b.offchain_total_sats)
                    .unwrap_or(0),
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
                max_sendable_sats: self
                    .state
                    .balance
                    .as_ref()
                    .map(|b| b.offchain_total_sats)
                    .unwrap_or(0),
                is_sending: false,
                error: None,
                confirmation: None,
            });
            self.emit_state();
            return;
        }

        // Try Lightning invoice
        if input.starts_with("ln") {
            self.state.send_flow = Some(SendFlowState {
                recipient: input,
                recipient_type: RecipientType::LightningInvoice,
                amount_sats: None,
                estimated_fee_sats: None,
                max_sendable_sats: self
                    .state
                    .balance
                    .as_ref()
                    .map(|b| b.offchain_total_sats)
                    .unwrap_or(0),
                is_sending: false,
                error: None,
                confirmation: None,
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
}
