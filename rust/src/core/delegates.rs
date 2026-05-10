use bitcoin::secp256k1::{Keypair, PublicKey, Secp256k1, SecretKey};
use tracing::{error, info};

use super::AppCore;
use crate::state::*;

impl AppCore {
    /// Generate a delegate: pre-sign settlement transactions that a delegate
    /// server can submit on our behalf when VTXOs need settling.
    pub(crate) fn handle_generate_delegate(&mut self) {
        if self.ark_client.is_none() {
            self.show_toast("Wallet not connected", true);
            return;
        }

        self.state.busy.settling = true;
        self.emit_state();

        let secp = Secp256k1::new();

        // Generate a cosigner keypair for this delegation.
        // The delegate server holds the other half — together they can settle.
        let cosigner_sk = SecretKey::new(&mut rand::thread_rng());
        let cosigner_kp = Keypair::from_secret_key(&secp, &cosigner_sk);
        let cosigner_pk = PublicKey::from_keypair(&cosigner_kp);

        let client = self.ark_client.as_ref().unwrap();

        // Step 1: Generate the delegate (unsigned PSBTs)
        let delegate_result = self.rt.block_on(client.generate_delegate(cosigner_pk));

        let mut delegate = match delegate_result {
            Ok(d) => d,
            Err(e) => {
                self.state.busy.settling = false;
                error!("generate delegate failed: {e}");
                self.show_toast(&format!("No VTXOs to delegate: {e}"), true);
                return;
            }
        };

        // Step 2: Sign the PSBTs with our keys
        let sign_result =
            client.sign_delegate_psbts(&mut delegate.intent.proof, &mut delegate.forfeit_psbts);

        if let Err(e) = sign_result {
            self.state.busy.settling = false;
            error!("sign delegate PSBTs failed: {e}");
            self.show_toast(&format!("Signing failed: {e}"), true);
            return;
        }

        // Step 3: Execute the delegate settlement
        let mut rng = rand::thread_rng();
        let settle_result =
            self.rt
                .block_on(client.settle_delegate(&mut rng, delegate, cosigner_kp));

        self.state.busy.settling = false;

        match settle_result {
            Ok(txid) => {
                info!("delegate settlement completed, txid: {}", txid);
                self.show_toast(&format!("Delegated settlement! TX: {}", txid), false);
                // Refresh balance
                self.handle_refresh_balance();
            }
            Err(e) => {
                error!("delegate settlement failed: {e}");
                self.show_toast(&format!("Delegate settlement failed: {e}"), true);
            }
        }
    }

    /// Load delegate management state.
    pub(crate) fn handle_load_delegates(&mut self) {
        // For now, show basic delegate info
        self.state.delegate_management = Some(DelegateManagementState {
            delegates: vec![],
            is_enabled: false,
        });
        self.emit_state();
    }
}
