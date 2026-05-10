use tracing::{error, info};

use super::AppCore;
use crate::state::*;
use crate::updates::*;

impl AppCore {
    /// Handle RefreshBalance — fetch offchain balance.
    pub(crate) fn handle_refresh_balance(&mut self) {
        if self.ark_client.is_none() {
            return;
        }

        self.state.busy.refreshing_balance = true;
        self.emit_state();

        let tx = self.core_tx.clone();
        let client = self.ark_client.as_ref().unwrap();

        let balance = self.rt.block_on(client.offchain_balance());

        match balance {
            Ok(bal) => {
                let confirmed = bal.confirmed().to_sat();
                let pre_confirmed = bal.pre_confirmed().to_sat();
                info!(
                    "balance: confirmed={}, pre_confirmed={}",
                    confirmed, pre_confirmed
                );
                let _ = tx.send(CoreMsg::Internal(Box::new(InternalEvent::BalanceFetched {
                    offchain_confirmed: confirmed,
                    offchain_pending: pre_confirmed,
                    onchain_confirmed: 0,
                    onchain_pending: 0,
                })));
            }
            Err(e) => {
                error!("balance fetch failed: {e}");
                let _ = tx.send(CoreMsg::Internal(Box::new(
                    InternalEvent::BalanceFetchFailed {
                        error: format!("{e}"),
                    },
                )));
            }
        }
    }

    /// Handle RefreshTransactionHistory.
    pub(crate) fn handle_refresh_history(&mut self) {
        if self.ark_client.is_none() {
            return;
        }

        let tx = self.core_tx.clone();
        let client = self.ark_client.as_ref().unwrap();
        let history = self.rt.block_on(client.transaction_history());

        match history {
            Ok(txs) => {
                info!("fetched {} transactions", txs.len());
                let items: Vec<TransactionItem> = txs
                    .iter()
                    .map(|t| match t {
                        ark_core::history::Transaction::Boarding {
                            txid,
                            amount,
                            confirmed_at,
                        } => TransactionItem {
                            txid: txid.to_string(),
                            tx_type: TransactionType::Boarding,
                            amount_sats: amount.to_sat() as i64,
                            is_settled: confirmed_at.is_some(),
                            timestamp: *confirmed_at,
                            display_time: format_timestamp(*confirmed_at),
                            asset_id: None,
                            asset_ticker: None,
                        },
                        ark_core::history::Transaction::Commitment {
                            txid,
                            amount,
                            created_at,
                        } => TransactionItem {
                            txid: txid.to_string(),
                            tx_type: TransactionType::Commitment,
                            amount_sats: amount.to_sat(),
                            is_settled: true,
                            timestamp: Some(*created_at),
                            display_time: format_timestamp(Some(*created_at)),
                            asset_id: None,
                            asset_ticker: None,
                        },
                        ark_core::history::Transaction::Ark {
                            txid,
                            amount,
                            is_settled,
                            created_at,
                        } => TransactionItem {
                            txid: txid.to_string(),
                            tx_type: TransactionType::Ark,
                            amount_sats: amount.to_sat(),
                            is_settled: *is_settled,
                            timestamp: Some(*created_at),
                            display_time: format_timestamp(Some(*created_at)),
                            asset_id: None,
                            asset_ticker: None,
                        },
                        ark_core::history::Transaction::Offboard {
                            commitment_txid,
                            amount,
                            confirmed_at,
                        } => TransactionItem {
                            txid: commitment_txid.to_string(),
                            tx_type: TransactionType::Offboard,
                            amount_sats: -(amount.to_sat() as i64),
                            is_settled: confirmed_at.is_some(),
                            timestamp: *confirmed_at,
                            display_time: format_timestamp(*confirmed_at),
                            asset_id: None,
                            asset_ticker: None,
                        },
                    })
                    .collect();

                let _ = tx.send(CoreMsg::Internal(Box::new(
                    InternalEvent::TransactionsFetched {
                        transactions: items,
                    },
                )));
            }
            Err(e) => {
                error!("transaction history failed: {e}");
            }
        }
    }
}

fn format_timestamp(ts: Option<i64>) -> String {
    match ts {
        Some(secs) => {
            let now = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs() as i64;
            let mins_ago = (now - secs) / 60;

            if mins_ago < 1 {
                "Just now".to_string()
            } else if mins_ago < 60 {
                format!("{}m ago", mins_ago)
            } else if mins_ago < 1440 {
                format!("{}h ago", mins_ago / 60)
            } else {
                format!("{}d ago", mins_ago / 1440)
            }
        }
        None => "Pending".to_string(),
    }
}
