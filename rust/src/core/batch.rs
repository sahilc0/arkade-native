use bitcoin::OutPoint;
use std::str::FromStr;
use tracing::{error, info};

use super::AppCore;
use crate::state::*;

impl AppCore {
    /// Settle all VTXOs and boarding outputs into the next batch.
    pub(crate) fn handle_settle(&mut self) {
        if self.ark_client.is_none() {
            self.show_toast("Wallet not connected", true);
            return;
        }

        self.state.busy.settling = true;
        self.emit_state();

        let mut rng = rand::thread_rng();
        let client = self.ark_client.as_ref().unwrap();

        // Ensure boarding address is known
        let _ = client.get_boarding_address();

        let result = self.rt.block_on(client.settle(&mut rng));

        self.state.busy.settling = false;

        match result {
            Ok(Some(txid)) => {
                info!("settled, batch txid: {}", txid);
                self.show_toast(&format!("Settled! Batch TX: {}", txid), false);
            }
            Ok(None) => {
                info!("nothing to settle");
                self.show_toast("Nothing to settle", false);
            }
            Err(e) => {
                error!("settle failed: {e}");
                self.show_toast(&format!("Settle failed: {e}"), true);
            }
        }
    }

    /// Settle specific VTXOs by outpoint.
    pub(crate) fn handle_settle_vtxos(&mut self, outpoints: Vec<String>) {
        if self.ark_client.is_none() {
            self.show_toast("Wallet not connected", true);
            return;
        }

        let parsed: Result<Vec<OutPoint>, _> =
            outpoints.iter().map(|s| OutPoint::from_str(s)).collect();

        let outpoints = match parsed {
            Ok(ops) => ops,
            Err(e) => {
                self.show_toast(&format!("Invalid outpoint: {e}"), true);
                return;
            }
        };

        self.state.busy.settling = true;
        self.emit_state();

        let mut rng = rand::thread_rng();
        let client = self.ark_client.as_ref().unwrap();
        let result = self
            .rt
            .block_on(client.settle_vtxos(&mut rng, &outpoints, &[]));

        self.state.busy.settling = false;

        match result {
            Ok(Some(txid)) => {
                info!("settled VTXOs, batch txid: {}", txid);
                self.show_toast(&format!("Settled! Batch TX: {}", txid), false);
            }
            Ok(None) => {
                self.show_toast("Nothing to settle", false);
            }
            Err(e) => {
                error!("settle VTXOs failed: {e}");
                self.show_toast(&format!("Settle failed: {e}"), true);
            }
        }
    }

    /// Load VTXOs for the VTXO management screen.
    pub(crate) fn handle_load_vtxos(&mut self) {
        if self.ark_client.is_none() {
            return;
        }

        let client = self.ark_client.as_ref().unwrap();
        let result = self.rt.block_on(client.list_vtxos());

        match result {
            Ok((vtxo_list, _script_map)) => {
                let mut items = Vec::new();
                let mut total = 0u64;

                for vtxo in vtxo_list.confirmed() {
                    let amount = vtxo.amount.to_sat();
                    total += amount;
                    items.push(VtxoItem {
                        outpoint: vtxo.outpoint.to_string(),
                        amount_sats: amount,
                        status: VtxoStatus::Confirmed,
                        expiry_display: format!("expires_at: {}", vtxo.expires_at),
                        is_selected: false,
                    });
                }
                for vtxo in vtxo_list.pre_confirmed() {
                    let amount = vtxo.amount.to_sat();
                    total += amount;
                    items.push(VtxoItem {
                        outpoint: vtxo.outpoint.to_string(),
                        amount_sats: amount,
                        status: VtxoStatus::PreConfirmed,
                        expiry_display: format!("expires_at: {}", vtxo.expires_at),
                        is_selected: false,
                    });
                }

                self.state.vtxo_management = Some(VtxoManagementState {
                    vtxos: items,
                    total_sats: total,
                });
                self.emit_state();
            }
            Err(e) => {
                error!("list VTXOs failed: {e}");
                self.show_toast(&format!("Failed to load VTXOs: {e}"), true);
            }
        }
    }
}
