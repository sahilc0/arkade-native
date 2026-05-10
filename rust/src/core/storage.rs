use std::collections::HashMap;
use std::sync::RwLock;

use ark_client::wallet::Persistence;
use ark_core::BoardingOutput;
use bitcoin::secp256k1::{SecretKey, XOnlyPublicKey};

/// In-memory persistence for boarding outputs.
/// Mirrors the pattern from ark-client-sample.
#[derive(Default)]
pub struct InMemoryPersistence {
    boarding_outputs: RwLock<HashMap<BoardingOutput, SecretKey>>,
}

impl Persistence for InMemoryPersistence {
    fn save_boarding_output(
        &self,
        sk: SecretKey,
        boarding_output: BoardingOutput,
    ) -> Result<(), ark_client::Error> {
        self.boarding_outputs
            .write()
            .map_err(|e| ark_client::Error::consumer(format!("failed to get write lock: {e}")))?
            .insert(boarding_output, sk);
        Ok(())
    }

    fn load_boarding_outputs(&self) -> Result<Vec<BoardingOutput>, ark_client::Error> {
        Ok(self
            .boarding_outputs
            .read()
            .map_err(|e| ark_client::Error::consumer(format!("failed to get read lock: {e}")))?
            .keys()
            .cloned()
            .collect())
    }

    fn sk_for_pk(&self, pk: &XOnlyPublicKey) -> Result<SecretKey, ark_client::Error> {
        let maybe_sk = self
            .boarding_outputs
            .read()
            .map_err(|e| ark_client::Error::consumer(format!("failed to get read lock: {e}")))?
            .iter()
            .find_map(|(b, sk)| if b.owner_pk() == *pk { Some(*sk) } else { None });

        maybe_sk
            .ok_or_else(|| ark_client::Error::consumer(format!("could not find SK for PK {pk}")))
    }
}
