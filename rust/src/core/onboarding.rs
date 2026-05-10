use std::sync::Arc;
use std::time::Duration;

use ark_bdk_wallet::Wallet;
use ark_client::{OfflineClient, SqliteSwapStorage, StaticKeyProvider};
use bitcoin::bip32::{ChildNumber, DerivationPath, Xpriv};
use bitcoin::key::{Keypair, Secp256k1};
use bitcoin::Network;
use secp256k1::SecretKey;
use tracing::{error, info};

use super::blockchain::EsploraBlockchain;
use super::storage::InMemoryPersistence;
use super::AppCore;
use crate::state::*;
use crate::updates::*;

/// Concrete Ark client type used throughout the app.
pub type ArkClient = ark_client::Client<
    EsploraBlockchain,
    Wallet<InMemoryPersistence>,
    SqliteSwapStorage,
    StaticKeyProvider,
>;

/// Network configuration.
pub struct NetworkConfig {
    pub ark_server_url: String,
    pub esplora_url: String,
    pub boltz_url: String,
    pub network: Network,
}

impl NetworkConfig {
    pub fn for_network(network: &str) -> Self {
        match network {
            "bitcoin" => Self {
                ark_server_url: "https://arkade.computer".to_string(),
                esplora_url: "https://blockstream.info/api".to_string(),
                boltz_url: "https://api.ark.boltz.exchange".to_string(),
                network: Network::Bitcoin,
            },
            "signet" => Self {
                ark_server_url: "https://signet.arkade.sh".to_string(),
                esplora_url: "https://mutinynet.com/signet/api".to_string(),
                boltz_url: "https://boltz.signet.arkade.sh".to_string(),
                network: Network::Signet,
            },
            _ => Self {
                // mutinynet (default)
                ark_server_url: "https://mutinynet.arkade.sh".to_string(),
                esplora_url: "https://mutinynet.com/api".to_string(),
                boltz_url: "https://api.boltz.mutinynet.arkade.sh".to_string(),
                network: Network::Regtest,
            },
        }
    }
}

impl AppCore {
    /// Handle CreateWallet action — generate mnemonic, connect to ASP.
    pub(crate) fn handle_create_wallet(&mut self, _password: String) {
        info!("creating new wallet");
        self.state.busy.creating_wallet = true;
        self.emit_state();

        let mnemonic = match bip39::Mnemonic::generate(12) {
            Ok(m) => m,
            Err(e) => {
                self.state.busy.creating_wallet = false;
                self.show_toast(&format!("Failed to generate mnemonic: {e}"), true);
                return;
            }
        };

        let private_key = match private_key_from_mnemonic(&mnemonic, &self.network) {
            Ok(private_key) => private_key,
            Err(e) => {
                self.state.busy.creating_wallet = false;
                self.show_toast(&format!("Failed to derive private key: {e}"), true);
                return;
            }
        };

        self.start_wallet_init(private_key, true);
    }

    /// Handle RestoreWallet action — parse nsec/hex private key, connect to ASP.
    pub(crate) fn handle_restore_wallet(&mut self, private_key_input: String, _password: String) {
        info!("restoring wallet from private key");
        self.state.busy.restoring_wallet = true;
        self.emit_state();

        let private_key = match parse_private_key(&private_key_input) {
            Ok(private_key) => private_key,
            Err(e) => {
                self.state.busy.restoring_wallet = false;
                self.show_toast(&format!("Invalid private key: {e}"), true);
                return;
            }
        };

        self.start_wallet_init(private_key, false);
    }

    /// Common initialization path for both create and restore.
    fn start_wallet_init(&mut self, private_key: SecretKey, _is_new: bool) {
        let network_config = NetworkConfig::for_network(&self.network);
        let data_dir = self.data_dir.clone();
        let tx = self.core_tx.clone();

        // Store private key to file.
        let private_key_path = format!("{}/private_key", data_dir);
        if let Err(e) = std::fs::write(&private_key_path, hex::encode(private_key.secret_bytes())) {
            error!("failed to store private key: {e}");
            self.state.busy.creating_wallet = false;
            self.state.busy.restoring_wallet = false;
            self.show_toast(&format!("Failed to store private key: {e}"), true);
            return;
        }

        // Update auth state
        self.state.auth = AuthState::Connecting;
        self.emit_state();

        // Spawn async connection to the Ark server
        self.rt.spawn(async move {
            match connect_to_ark(private_key, &network_config, &data_dir).await {
                Ok((client, pubkey)) => {
                    let _ = tx.send(CoreMsg::Internal(Box::new(
                        InternalEvent::WalletInitialized {
                            mnemonic: String::new(),
                            pubkey: pubkey.clone(),
                        },
                    )));
                    let _ = tx.send(CoreMsg::Internal(Box::new(InternalEvent::ArkClientReady {
                        client: Box::new(client),
                    })));
                }
                Err(e) => {
                    error!("failed to connect: {e:#}");
                    let _ = tx.send(CoreMsg::Internal(Box::new(
                        InternalEvent::WalletInitFailed {
                            error: format!("{e:#}"),
                        },
                    )));
                }
            }
        });
    }

    /// Handle UnlockWallet — load mnemonic from storage and reconnect.
    pub(crate) fn handle_unlock_wallet(&mut self, _password: String) {
        info!("unlocking wallet");
        self.state.busy.connecting = true;
        self.emit_state();

        let private_key = match self.load_private_key() {
            Ok(private_key) => private_key,
            Err(e) => {
                self.state.busy.connecting = false;
                self.show_toast(&format!("No private key found: {e}"), true);
                return;
            }
        };

        self.start_wallet_init(private_key, false);
    }

    /// Handle wallet initialization success.
    pub(crate) fn handle_wallet_initialized(&mut self, pubkey: String) {
        info!("wallet connected, pubkey: {}", pubkey);
        self.state.auth = AuthState::Connected {
            pubkey: pubkey.clone(),
        };
        self.state.busy.creating_wallet = false;
        self.state.busy.restoring_wallet = false;
        self.state.busy.connecting = false;
        self.state.balance = Some(BalanceState::default());
        self.state.addresses = Some(AddressesState::default());
        self.state.router.screen_stack = vec![Screen::Home];
        self.emit_state();
    }

    /// Handle wallet initialization failure.
    pub(crate) fn handle_wallet_init_failed(&mut self, error: String) {
        self.state.busy.creating_wallet = false;
        self.state.busy.restoring_wallet = false;
        self.state.busy.connecting = false;
        self.state.auth = AuthState::Unauthenticated;
        self.show_toast(&format!("Connection failed: {error}"), true);
    }

    /// Handle the ArkClient being ready (store it).
    pub(crate) fn handle_ark_client_ready(&mut self, client: ArkClient) {
        info!("ark client ready");
        self.ark_client = Some(client);
        self.fetch_addresses();

        // Try to claim any pending swaps from previous sessions
        self.handle_claim_pending_swaps();
    }

    /// Fetch wallet addresses from the connected client.
    fn fetch_addresses(&mut self) {
        if let Some(client) = &self.ark_client {
            match client.get_offchain_address() {
                Ok((addr, _)) => {
                    if let Some(addrs) = &mut self.state.addresses {
                        addrs.offchain_address = Some(addr.encode());
                    }
                }
                Err(e) => {
                    error!("failed to get offchain address: {e}");
                }
            }

            match client.get_boarding_address() {
                Ok(addr) => {
                    if let Some(addrs) = &mut self.state.addresses {
                        addrs.boarding_address = Some(addr.to_string());
                    }
                }
                Err(e) => {
                    error!("failed to get boarding address: {e}");
                }
            }

            self.emit_state();
        }
    }

    /// Check if a wallet exists on disk (for startup flow).
    pub(crate) fn check_existing_wallet(&mut self) {
        let private_key_path = format!("{}/private_key", self.data_dir);
        let mnemonic_path = format!("{}/mnemonic", self.data_dir);
        if std::path::Path::new(&private_key_path).exists()
            || std::path::Path::new(&mnemonic_path).exists()
        {
            self.handle_unlock_wallet(String::new());
        } else {
            self.state.auth = AuthState::Unauthenticated;
            self.state.router.screen_stack = vec![Screen::Init];
            self.emit_state();
        }
    }

    fn load_private_key(&self) -> anyhow::Result<SecretKey> {
        let private_key_path = format!("{}/private_key", self.data_dir);
        if let Ok(private_key) = std::fs::read_to_string(&private_key_path) {
            return parse_private_key(&private_key);
        }

        let mnemonic_path = format!("{}/mnemonic", self.data_dir);
        let mnemonic_str = std::fs::read_to_string(&mnemonic_path)?;
        let mnemonic = bip39::Mnemonic::parse_normalized(mnemonic_str.trim())?;
        let private_key = private_key_from_mnemonic(&mnemonic, &self.network)?;
        std::fs::write(&private_key_path, hex::encode(private_key.secret_bytes()))?;
        Ok(private_key)
    }
}

/// Connect to the Ark server (async).
async fn connect_to_ark(
    private_key: SecretKey,
    config: &NetworkConfig,
    data_dir: &str,
) -> anyhow::Result<(ArkClient, String)> {
    let _ = rustls::crypto::ring::default_provider().install_default();

    let secp = Secp256k1::new();
    let keypair = Keypair::from_secret_key(&secp, &private_key);

    let esplora = EsploraBlockchain::new(&config.esplora_url)?;
    let esplora = Arc::new(esplora);

    let swap_db_path = format!("{}/swaps.sqlite", data_dir);
    let swap_storage = Arc::new(
        SqliteSwapStorage::new(&swap_db_path)
            .await
            .map_err(|e| anyhow::anyhow!("{e}"))?,
    );

    let db = InMemoryPersistence::default();
    let wallet = Wallet::new(keypair, secp, config.network, &config.esplora_url, db)?;
    let wallet = Arc::new(wallet);

    let offline = OfflineClient::<_, _, _, StaticKeyProvider>::new_with_keypair(
        "arkade-native".to_string(),
        keypair,
        esplora,
        wallet,
        config.ark_server_url.clone(),
        swap_storage,
        config.boltz_url.clone(),
        Duration::from_secs(30),
    );

    info!("connecting to Ark server at {}", config.ark_server_url);

    let client = offline.connect().await.map_err(|e| {
        error!("Ark connect error details: {:?}", e);
        anyhow::anyhow!("failed to connect to Ark server: {e}")
    })?;

    let (address, _) = client
        .get_offchain_address()
        .map_err(|e| anyhow::anyhow!("{e}"))?;
    let pubkey = address.encode();

    info!("connected! address: {}", pubkey);

    Ok((client, pubkey))
}

fn private_key_from_mnemonic(
    mnemonic: &bip39::Mnemonic,
    network: &str,
) -> anyhow::Result<SecretKey> {
    let network_config = NetworkConfig::for_network(network);
    let secp = Secp256k1::new();
    let seed = mnemonic.to_seed("");
    let xpriv = Xpriv::new_master(network_config.network, &seed)?;
    let path = DerivationPath::from(vec![
        ChildNumber::Hardened { index: 44 },
        ChildNumber::Hardened { index: 1237 },
        ChildNumber::Hardened { index: 0 },
        ChildNumber::Normal { index: 0 },
        ChildNumber::Normal { index: 0 },
    ]);
    let derived = xpriv.derive_priv(&secp, &path)?;
    Ok(derived.private_key)
}

fn parse_private_key(input: &str) -> anyhow::Result<SecretKey> {
    let trimmed = input.trim();
    let bytes = if trimmed.starts_with("nsec") {
        let (hrp, bytes) = bech32::decode(trimmed)?;
        if hrp.as_str() != "nsec" {
            anyhow::bail!("nsec key must start with nsec");
        }
        bytes
    } else {
        hex::decode(trimmed)?
    };

    if bytes.len() != 32 {
        anyhow::bail!("private key must be 32 bytes");
    }

    SecretKey::from_slice(&bytes).map_err(|e| anyhow::anyhow!("{e}"))
}

#[cfg(test)]
mod tests {
    use super::parse_private_key;

    const FIXTURE_NSEC: &str = "nsec13374vlgh58p4sw9nrdc72rmf40x62qgvk6jac8rekwm872p0esesxqx6t5";
    const FIXTURE_HEX: &str = "8c7d567d17a1c35838b31b71e50f69abcda5010cb6a5dc1c79b3b67f282fcc33";

    #[test]
    fn parses_nsec_like_arkade_wallet() {
        let key = parse_private_key(FIXTURE_NSEC).expect("nsec fixture should parse");
        assert_eq!(hex::encode(key.secret_bytes()), FIXTURE_HEX);
    }

    #[test]
    fn parses_raw_hex_private_key() {
        let key = parse_private_key(FIXTURE_HEX).expect("hex fixture should parse");
        assert_eq!(hex::encode(key.secret_bytes()), FIXTURE_HEX);
    }
}
