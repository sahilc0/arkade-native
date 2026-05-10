use ark_client::{Blockchain, SpendStatus, TxStatus};
use ark_core::ExplorerUtxo;
use bitcoin::{Address, Amount, OutPoint, Transaction, Txid};
use esplora_client::OutputStatus;

/// Esplora-based blockchain client implementing the ark_client::Blockchain trait.
/// Mirrors the pattern from ark-client-sample.
pub struct EsploraBlockchain {
    client: esplora_client::AsyncClient,
}

impl EsploraBlockchain {
    pub fn new(url: &str) -> anyhow::Result<Self> {
        let builder = esplora_client::Builder::new(url);
        let client = builder.build_async()?;
        Ok(Self { client })
    }
}

impl Blockchain for EsploraBlockchain {
    async fn find_outpoints(
        &self,
        address: &Address,
    ) -> Result<Vec<ExplorerUtxo>, ark_client::Error> {
        let script_pubkey = address.script_pubkey();
        let txs = self
            .client
            .scripthash_txs(&script_pubkey, None)
            .await
            .map_err(ark_client::Error::consumer)?;

        let outputs: Vec<ExplorerUtxo> = txs
            .into_iter()
            .flat_map(|tx| {
                let txid = tx.txid;
                tx.vout
                    .iter()
                    .enumerate()
                    .filter(|(_, v)| v.scriptpubkey == script_pubkey)
                    .map(|(i, v)| ExplorerUtxo {
                        outpoint: OutPoint {
                            txid,
                            vout: i as u32,
                        },
                        amount: Amount::from_sat(v.value),
                        confirmation_blocktime: tx.status.block_time,
                        is_spent: false,
                    })
                    .collect::<Vec<_>>()
            })
            .collect();

        let mut utxos = Vec::new();
        for output in outputs.iter() {
            let outpoint = output.outpoint;
            let status = self
                .client
                .get_output_status(&outpoint.txid, outpoint.vout as u64)
                .await
                .map_err(ark_client::Error::consumer)?;

            match status {
                Some(OutputStatus { spent: false, .. }) | None => {
                    utxos.push(*output);
                }
                Some(OutputStatus { spent: true, .. }) => {
                    utxos.push(ExplorerUtxo {
                        is_spent: true,
                        ..*output
                    });
                }
            }
        }

        Ok(utxos)
    }

    async fn find_tx(&self, txid: &Txid) -> Result<Option<Transaction>, ark_client::Error> {
        self.client
            .get_tx(txid)
            .await
            .map_err(ark_client::Error::consumer)
    }

    async fn get_tx_status(&self, txid: &Txid) -> Result<TxStatus, ark_client::Error> {
        let info = self
            .client
            .get_tx_info(txid)
            .await
            .map_err(ark_client::Error::consumer)?;

        Ok(TxStatus {
            confirmed_at: info.and_then(|s| s.status.block_time.map(|t| t as i64)),
        })
    }

    async fn get_output_status(
        &self,
        txid: &Txid,
        vout: u32,
    ) -> Result<SpendStatus, ark_client::Error> {
        let status = self
            .client
            .get_output_status(txid, vout as u64)
            .await
            .map_err(ark_client::Error::consumer)?;

        Ok(SpendStatus {
            spend_txid: status.as_ref().and_then(|s| s.txid),
        })
    }

    async fn broadcast(&self, tx: &Transaction) -> Result<(), ark_client::Error> {
        self.client
            .broadcast(tx)
            .await
            .map_err(ark_client::Error::consumer)
    }

    async fn get_fee_rate(&self) -> Result<f64, ark_client::Error> {
        Ok(1.0)
    }

    async fn broadcast_package(&self, _txs: &[&Transaction]) -> Result<(), ark_client::Error> {
        // Not needed for mutinynet testing
        unimplemented!("broadcast_package not implemented")
    }
}
