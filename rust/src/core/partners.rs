use std::str::FromStr;

use bitcoin::bip32::{ChildNumber, DerivationPath, Xpriv};
use bitcoin::hashes::{sha256, Hash};
use bitcoin::key::Secp256k1;
use bitcoin::secp256k1::Message;

use super::onboarding::NetworkConfig;
use super::AppCore;
use crate::state::{PartnerAppKind, PartnerAppState};

impl AppCore {
    pub(crate) fn handle_load_partner_app(&mut self, app: PartnerAppKind) {
        self.state.partner_app = Some(PartnerAppState {
            app: app.clone(),
            url: None,
            is_loading: true,
            error: None,
        });
        self.emit_state();

        let result = match app {
            PartnerAppKind::Dfx => self.build_dfx_url(),
            PartnerAppKind::Lendasat => Ok("https://iframe.lendasat.com".to_string()),
        };

        self.state.partner_app = Some(match result {
            Ok(url) => PartnerAppState {
                app,
                url: Some(url),
                is_loading: false,
                error: None,
            },
            Err(err) => PartnerAppState {
                app,
                url: None,
                is_loading: false,
                error: Some(err),
            },
        });
        self.emit_state();
    }

    fn build_dfx_url(&self) -> Result<String, String> {
        let client = self
            .ark_client
            .as_ref()
            .ok_or_else(|| "Wallet not connected".to_string())?;

        let (address, _) = client
            .get_offchain_address()
            .map_err(|e| format!("Could not load Arkade address: {e}"))?;
        let offchain_addr = address.encode();

        let mnemonic_path = format!("{}/mnemonic", self.data_dir);
        let mnemonic = std::fs::read_to_string(&mnemonic_path)
            .map_err(|e| format!("Could not load wallet identity: {e}"))?;
        let mnemonic = bip39::Mnemonic::parse_normalized(mnemonic.trim())
            .map_err(|e| format!("Could not parse wallet identity: {e}"))?;

        let network = NetworkConfig::for_network(&self.network).network;
        let seed = mnemonic.to_seed("");
        let xpriv = Xpriv::new_master(network, &seed)
            .map_err(|e| format!("Could not derive wallet identity: {e}"))?;

        let secp = Secp256k1::new();
        let base_path = DerivationPath::from_str(ark_core::DEFAULT_DERIVATION_PATH)
            .map_err(|e| format!("Could not derive wallet identity path: {e}"))?;
        let identity_path = base_path.extend([ChildNumber::Normal { index: 0 }]);
        let identity = xpriv
            .derive_priv(&secp, &identity_path)
            .map_err(|e| format!("Could not derive wallet identity key: {e}"))?
            .to_keypair(&secp);

        let message = format!(
            "By_signing_this_message,_you_confirm_that_you_are_the_sole_owner_of_the_provided_Blockchain_address._Your_ID:_{offchain_addr}"
        );
        let digest = sha256::Hash::hash(message.as_bytes());
        let message = Message::from_digest_slice(digest.as_byte_array())
            .map_err(|e| format!("Could not prepare DFX signature: {e}"))?;
        let signature = secp.sign_ecdsa(&message, &identity.secret_key());
        let signature = hex::encode(signature.serialize_compact());

        Ok(format!(
            "https://app.dfx.swiss/buy/?address={}&signature={signature}&wallet=Arkade&headless=true",
            percent_encode(&offchain_addr)
        ))
    }
}

fn percent_encode(value: &str) -> String {
    let mut encoded = String::with_capacity(value.len());
    for byte in value.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                encoded.push(byte as char);
            }
            _ => encoded.push_str(&format!("%{byte:02X}")),
        }
    }
    encoded
}
