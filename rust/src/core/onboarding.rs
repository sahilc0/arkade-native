use std::sync::Arc;
use std::time::Duration;

use ark_bdk_wallet::Wallet;
use ark_client::{Bip32KeyProvider, OfflineClient, SqliteSwapStorage};
use bitcoin::bip32::Xpriv;
use bitcoin::key::Secp256k1;
use bitcoin::Network;
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
    Bip32KeyProvider,
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
        let mnemonic_str = mnemonic.to_string();

        self.start_wallet_init(mnemonic, mnemonic_str, true);
    }

    /// Handle RestoreWallet action — parse mnemonic, connect to ASP.
    pub(crate) fn handle_restore_wallet(&mut self, mnemonic_str: String, _password: String) {
        info!("restoring wallet from mnemonic");
        self.state.busy.restoring_wallet = true;
        self.emit_state();

        let mnemonic = match bip39::Mnemonic::parse_normalized(mnemonic_str.trim()) {
            Ok(m) => m,
            Err(e) => {
                self.state.busy.restoring_wallet = false;
                self.show_toast(&format!("Invalid mnemonic: {e}"), true);
                return;
            }
        };
        let mnemonic_string = mnemonic.to_string();

        self.start_wallet_init(mnemonic, mnemonic_string, false);
    }

    /// Common initialization path for both create and restore.
    fn start_wallet_init(&mut self, mnemonic: bip39::Mnemonic, mnemonic_str: String, is_new: bool) {
        let network_config = NetworkConfig::for_network(&self.network);
        let data_dir = self.data_dir.clone();
        let tx = self.core_tx.clone();

        // Store mnemonic to file
        let mnemonic_path = format!("{}/mnemonic", data_dir);
        if let Err(e) = std::fs::write(&mnemonic_path, &mnemonic_str) {
            error!("failed to store mnemonic: {e}");
            self.state.busy.creating_wallet = false;
            self.state.busy.restoring_wallet = false;
            self.show_toast(&format!("Failed to store mnemonic: {e}"), true);
            return;
        }

        // Derive xpriv from mnemonic
        let seed = mnemonic.to_seed("");
        let xpriv = match Xpriv::new_master(network_config.network, &seed) {
            Ok(x) => x,
            Err(e) => {
                self.state.busy.creating_wallet = false;
                self.state.busy.restoring_wallet = false;
                self.show_toast(&format!("Failed to derive key: {e}"), true);
                return;
            }
        };

        // If this is a new wallet, emit the mnemonic for display
        if is_new {
            let _ = self.update_tx.send(AppUpdate::WalletCreated {
                mnemonic: mnemonic_str,
            });
        }

        // Update auth state
        self.state.auth = AuthState::Connecting;
        self.emit_state();

        // Spawn async connection to the Ark server
        self.rt.spawn(async move {
            match connect_to_ark(xpriv, &network_config, &data_dir).await {
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

        let mnemonic_path = format!("{}/mnemonic", self.data_dir);
        let mnemonic_str = match std::fs::read_to_string(&mnemonic_path) {
            Ok(m) => m,
            Err(e) => {
                self.state.busy.connecting = false;
                self.show_toast(&format!("No wallet found: {e}"), true);
                return;
            }
        };

        let mnemonic = match bip39::Mnemonic::parse_normalized(mnemonic_str.trim()) {
            Ok(m) => m,
            Err(e) => {
                self.state.busy.connecting = false;
                self.show_toast(&format!("Invalid stored mnemonic: {e}"), true);
                return;
            }
        };

        self.start_wallet_init(mnemonic, mnemonic_str, false);
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
        let mnemonic_path = format!("{}/mnemonic", self.data_dir);
        if std::path::Path::new(&mnemonic_path).exists() {
            self.state.auth = AuthState::Locked;
            self.state.router.screen_stack = vec![Screen::Unlock];
        } else {
            self.state.auth = AuthState::Unauthenticated;
            self.state.router.screen_stack = vec![Screen::Init];
        }
        self.emit_state();
    }
}

/// Connect to the Ark server (async).
async fn connect_to_ark(
    xpriv: Xpriv,
    config: &NetworkConfig,
    data_dir: &str,
) -> anyhow::Result<(ArkClient, String)> {
    let _ = rustls::crypto::ring::default_provider().install_default();

    let secp = Secp256k1::new();

    let esplora = EsploraBlockchain::new(&config.esplora_url)?;
    let esplora = Arc::new(esplora);

    let swap_db_path = format!("{}/swaps.sqlite", data_dir);
    let swap_storage = Arc::new(
        SqliteSwapStorage::new(&swap_db_path)
            .await
            .map_err(|e| anyhow::anyhow!("{e}"))?,
    );

    let db = InMemoryPersistence::default();
    let wallet = Wallet::new_from_xpriv(xpriv, secp, config.network, &config.esplora_url, db)?;
    let wallet = Arc::new(wallet);

    let offline = OfflineClient::<_, _, _, Bip32KeyProvider>::new_with_bip32(
        "arkade-native".to_string(),
        xpriv,
        None,
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
