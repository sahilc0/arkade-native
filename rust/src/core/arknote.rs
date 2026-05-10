use ark_core::ArkNote;
use tracing::{error, info};

use super::AppCore;
use crate::state::*;

impl AppCore {
    /// Parse an ArkNote string.
    pub(crate) fn handle_parse_arknote(&mut self, input: String) {
        match ArkNote::from_string(input.trim()) {
            Ok(note) => {
                let amount = note.value().to_sat();
                info!("parsed arknote: {} sats", amount);
                self.state.arknote_flow = Some(ArkNoteFlowState {
                    note_input: input,
                    parsed_amount_sats: Some(amount),
                    is_redeeming: false,
                    error: None,
                    redeemed_amount_sats: None,
                });
                self.emit_state();
            }
            Err(e) => {
                self.state.arknote_flow = Some(ArkNoteFlowState {
                    note_input: input,
                    parsed_amount_sats: None,
                    is_redeeming: false,
                    error: Some(format!("Invalid ArkNote: {e}")),
                    redeemed_amount_sats: None,
                });
                self.emit_state();
            }
        }
    }

    /// Redeem the parsed ArkNote by settling it into the next batch.
    pub(crate) fn handle_confirm_redeem_arknote(&mut self) {
        if self.ark_client.is_none() {
            self.show_toast("Wallet not connected", true);
            return;
        }

        let flow = match &self.state.arknote_flow {
            Some(f) => f.clone(),
            None => {
                self.show_toast("No ArkNote to redeem", true);
                return;
            }
        };

        let note = match ArkNote::from_string(flow.note_input.trim()) {
            Ok(n) => n,
            Err(e) => {
                self.show_toast(&format!("Invalid ArkNote: {e}"), true);
                return;
            }
        };

        if let Some(f) = &mut self.state.arknote_flow {
            f.is_redeeming = true;
        }
        self.emit_state();

        let mut rng = rand::thread_rng();
        let client = self.ark_client.as_ref().unwrap();

        // Settle with the note
        let result = self
            .rt
            .block_on(client.settle_with_notes(&mut rng, vec![note]));

        match result {
            Ok(Some(txid)) => {
                let amount = flow.parsed_amount_sats.unwrap_or(0);
                info!("arknote redeemed: {} sats, txid: {}", amount, txid);
                if let Some(f) = &mut self.state.arknote_flow {
                    f.is_redeeming = false;
                    f.redeemed_amount_sats = Some(amount);
                }
                self.show_toast(&format!("Redeemed {} sats!", amount), false);
            }
            Ok(None) => {
                if let Some(f) = &mut self.state.arknote_flow {
                    f.is_redeeming = false;
                }
                self.show_toast("ArkNote redemption returned no transaction", true);
            }
            Err(e) => {
                error!("arknote redeem failed: {e}");
                if let Some(f) = &mut self.state.arknote_flow {
                    f.is_redeeming = false;
                    f.error = Some(format!("{e}"));
                }
                self.show_toast(&format!("Redeem failed: {e}"), true);
            }
        }
    }

    /// Cancel ArkNote redemption.
    pub(crate) fn handle_cancel_arknote(&mut self) {
        self.state.arknote_flow = None;
        self.emit_state();
    }
}
