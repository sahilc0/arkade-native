pub mod arknote;
pub mod assets;
pub mod backup;
pub mod batch;
pub mod blockchain;
pub mod boltz;
pub mod delegates;
pub mod onboarding;
pub mod partners;
pub mod receive;
pub mod send;
pub mod settings;
pub mod storage;
pub mod wallet;

use std::sync::{Arc, RwLock};

use flume::Sender;
use tracing::{info, warn};

use crate::actions::AppAction;
use crate::state::*;
use crate::updates::*;

/// The core actor — owns all mutable state and processes messages sequentially.
pub(crate) struct AppCore {
    // Channels
    pub(crate) update_tx: Sender<AppUpdate>,
    pub(crate) core_tx: Sender<CoreMsg>,

    // Tokio runtime for async operations
    pub(crate) rt: tokio::runtime::Runtime,

    // Application state
    pub(crate) state: AppState,
    shared_state: Arc<RwLock<AppState>>,

    // Ark SDK client (set after successful connection)
    pub(crate) ark_client: Option<onboarding::ArkClient>,

    // Config
    pub(crate) data_dir: String,
    pub(crate) network: String,

    // Internal revision counter
    rev: u64,
}

impl AppCore {
    pub(crate) fn new(
        update_tx: Sender<AppUpdate>,
        core_tx: Sender<CoreMsg>,
        shared_state: Arc<RwLock<AppState>>,
        data_dir: String,
        network: String,
    ) -> Self {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .expect("failed to create tokio runtime");

        let mut core = Self {
            update_tx,
            core_tx,
            rt,
            state: AppState::default(),
            shared_state,
            ark_client: None,
            data_dir,
            network,
            rev: 0,
        };

        // Check if wallet exists on disk
        core.check_existing_wallet();

        core
    }

    /// Main message handler — called sequentially from the actor loop.
    pub(crate) fn handle_message(&mut self, msg: CoreMsg) {
        match msg {
            CoreMsg::Action(action) => self.handle_action(action),
            CoreMsg::Internal(event) => self.handle_internal(*event),
        }
    }

    fn handle_action(&mut self, action: AppAction) {
        info!("action: {:?}", std::mem::discriminant(&action));

        match action {
            // Navigation
            AppAction::PushScreen { screen } => {
                self.state.router.screen_stack.push(screen);
                self.emit_state();
            }
            AppAction::PopScreen => {
                if self.state.router.screen_stack.len() > 1 {
                    self.state.router.screen_stack.pop();
                }
                self.emit_state();
            }
            AppAction::ReplaceScreen { screen } => {
                if let Some(last) = self.state.router.screen_stack.last_mut() {
                    *last = screen;
                }
                self.emit_state();
            }

            // Lifecycle
            AppAction::Foregrounded => {
                info!("app foregrounded");
            }
            AppAction::Backgrounded => {
                info!("app backgrounded");
            }
            AppAction::ClearToast => {
                self.state.toast = None;
                self.emit_state();
            }

            // Onboarding
            AppAction::CreateWallet { password } => {
                self.handle_create_wallet(password);
            }
            AppAction::RestoreWallet { mnemonic, password } => {
                self.handle_restore_wallet(mnemonic, password);
            }
            AppAction::UnlockWallet { password } => {
                self.handle_unlock_wallet(password);
            }

            // Wallet
            AppAction::RefreshBalance => {
                self.handle_refresh_balance();
            }
            AppAction::RefreshTransactionHistory => {
                self.handle_refresh_history();
            }
            AppAction::RefreshAll => {
                self.handle_refresh_balance();
                self.handle_refresh_history();
            }

            // Send
            AppAction::ParseRecipient { input } => {
                self.handle_parse_recipient(input);
            }
            AppAction::SetSendAmount { sats } => {
                self.handle_set_send_amount(sats);
            }
            AppAction::EstimateSendFee => {
                // TODO: implement fee estimation
            }
            AppAction::ConfirmSend => {
                self.handle_confirm_send();
            }
            AppAction::CancelSend => {
                self.handle_cancel_send();
            }

            // Receive
            AppAction::SetReceiveType { receive_type } => {
                self.handle_set_receive_type(receive_type);
            }
            AppAction::SetReceiveAmount { sats } => {
                self.handle_set_receive_amount(sats);
            }
            AppAction::GenerateReceiveAddress => {
                self.handle_generate_receive_address();
            }
            AppAction::GenerateLightningInvoice { amount_sats } => {
                self.handle_reverse_swap(amount_sats);
            }

            // ArkNotes
            AppAction::ParseArkNote { input } => {
                self.handle_parse_arknote(input);
            }
            AppAction::ConfirmRedeemArkNote => {
                self.handle_confirm_redeem_arknote();
            }
            AppAction::CancelArkNoteRedeem => {
                self.handle_cancel_arknote();
            }

            // Settle
            AppAction::Settle => {
                self.handle_settle();
            }
            AppAction::SettleVtxos { outpoints } => {
                self.handle_settle_vtxos(outpoints);
            }
            AppAction::LoadVtxos => {
                self.handle_load_vtxos();
            }

            // Boltz Swaps
            AppAction::ConnectBoltz => {
                self.handle_connect_boltz();
            }
            AppAction::CreateSubmarineSwap { invoice } => {
                self.handle_submarine_swap(invoice);
            }
            AppAction::CreateReverseSwap { amount_sats } => {
                self.handle_reverse_swap(amount_sats);
            }
            AppAction::CreateArkToBtcSwap { .. } | AppAction::CreateBtcToArkSwap { .. } => {
                self.show_toast("Chain swaps not yet implemented", true);
            }
            AppAction::DisconnectBoltz => {
                self.handle_disconnect_boltz();
            }
            AppAction::ClaimSwap { swap_id } => {
                self.handle_claim_swap(swap_id);
            }
            AppAction::RefundSwap { swap_id } => {
                self.handle_refund_swap(swap_id);
            }
            AppAction::RefreshSwapHistory => {
                self.handle_refresh_swap_history();
            }

            // Settings (immediate state changes)
            AppAction::SetTheme { theme } => {
                self.state.config.theme = theme;
                self.emit_state();
            }
            AppAction::SetDisplayUnit { unit } => {
                self.state.config.display_unit = unit;
                self.emit_state();
            }
            AppAction::SetFiatCurrency { currency } => {
                self.state.config.fiat_currency = currency;
                self.emit_state();
            }
            AppAction::SetCurrencyDisplay { display } => {
                self.state.config.currency_display = display;
                self.emit_state();
            }
            AppAction::SetHaptics { enabled } => {
                self.state.config.haptics_enabled = enabled;
                self.emit_state();
            }
            AppAction::SetNotifications { enabled } => {
                self.state.config.notifications_enabled = enabled;
                self.emit_state();
            }
            AppAction::SetShowBalance { show } => {
                self.state.config.show_balance = show;
                self.emit_state();
            }

            // Assets
            AppAction::RefreshAssets => {
                self.handle_refresh_assets();
            }
            AppAction::MintAsset {
                name,
                ticker,
                amount,
                decimals,
            } => {
                self.handle_mint_asset(name, ticker, amount, decimals);
            }
            AppAction::BurnAsset { asset_id, amount } => {
                self.handle_burn_asset(asset_id, amount);
            }
            AppAction::ReissueAsset { asset_id, amount } => {
                self.handle_reissue_asset(asset_id, amount);
            }
            AppAction::ImportAsset { asset_id } => {
                self.handle_import_asset(asset_id);
            }
            AppAction::RemoveImportedAsset { .. } => {}
            AppAction::TransferAsset {
                asset_id,
                recipient,
                amount,
            } => {
                self.handle_transfer_asset(asset_id, recipient, amount);
            }

            // Partner apps
            AppAction::LoadPartnerApp { app } => {
                self.handle_load_partner_app(app);
            }
            AppAction::ClearPartnerApp => {
                self.state.partner_app = None;
                self.emit_state();
            }

            // Settings
            AppAction::ChangePassword {
                old_password,
                new_password,
            } => {
                self.handle_change_password(old_password, new_password);
            }
            AppAction::SetAspUrl { url } => {
                self.handle_set_asp_url(url);
            }
            AppAction::SetDelegateEnabled { enabled } => {
                if enabled {
                    self.handle_generate_delegate();
                }
            }
            AppAction::AddDelegate { .. } | AppAction::RemoveDelegate { .. } => {
                self.handle_load_delegates();
            }

            // Backup
            AppAction::RevealMnemonic { password } => {
                self.handle_reveal_mnemonic(password);
            }
            AppAction::EnableNostrBackup => {
                self.handle_enable_nostr_backup();
            }
            AppAction::DisableNostrBackup => {
                self.handle_disable_nostr_backup();
            }

            // VTXO management
            AppAction::ToggleVtxoSelection { outpoint } => {
                if let Some(mgmt) = &mut self.state.vtxo_management {
                    if let Some(vtxo) = mgmt.vtxos.iter_mut().find(|v| v.outpoint == outpoint) {
                        vtxo.is_selected = !vtxo.is_selected;
                    }
                }
                self.emit_state();
            }
            AppAction::SettleSelectedVtxos => {
                if let Some(mgmt) = &self.state.vtxo_management {
                    let selected: Vec<String> = mgmt
                        .vtxos
                        .iter()
                        .filter(|v| v.is_selected)
                        .map(|v| v.outpoint.clone())
                        .collect();
                    if !selected.is_empty() {
                        self.handle_settle_vtxos(selected);
                    }
                }
            }

            // Reset
            AppAction::ResetWallet => {
                let mnemonic_path = format!("{}/mnemonic", self.data_dir);
                let _ = std::fs::remove_file(&mnemonic_path);
                let private_key_path = format!("{}/private_key", self.data_dir);
                let _ = std::fs::remove_file(&private_key_path);
                let swaps_path = format!("{}/swaps.sqlite", self.data_dir);
                let _ = std::fs::remove_file(&swaps_path);
                self.ark_client = None;
                self.state = AppState::default();
                self.state.router.screen_stack = vec![Screen::Init];
                self.emit_state();
            }

            // Biometric unlock
            AppAction::UnlockWithBiometrics => {
                // Requires platform callback
                self.show_toast("Biometrics not available in CLI", true);
            }
        }
    }

    fn handle_internal(&mut self, event: InternalEvent) {
        match event {
            // Onboarding results
            InternalEvent::WalletInitialized { pubkey, .. } => {
                self.handle_wallet_initialized(pubkey);
            }
            InternalEvent::WalletInitFailed { error } => {
                self.handle_wallet_init_failed(error);
            }
            InternalEvent::ArkClientReady { client } => {
                self.handle_ark_client_ready(*client);
            }

            // Balance results
            InternalEvent::BalanceFetched {
                offchain_confirmed,
                offchain_pending,
                onchain_confirmed,
                onchain_pending,
            } => {
                self.state.busy.refreshing_balance = false;
                self.state.balance = Some(BalanceState {
                    offchain_confirmed_sats: offchain_confirmed,
                    offchain_pending_sats: offchain_pending,
                    offchain_total_sats: offchain_confirmed + offchain_pending,
                    onchain_confirmed_sats: onchain_confirmed,
                    onchain_pending_sats: onchain_pending,
                    fiat_value: None,
                    next_rollover_timestamp: None,
                });
                self.emit_state();
            }
            InternalEvent::BalanceFetchFailed { error } => {
                self.state.busy.refreshing_balance = false;
                self.show_toast(&format!("Balance fetch failed: {error}"), true);
            }

            // Transaction results
            InternalEvent::TransactionsFetched { transactions } => {
                self.state.transactions = transactions;
                self.emit_state();
            }

            // Toast
            InternalEvent::ShowToast { message, is_error } => {
                self.state.toast = Some(Toast { message, is_error });
                self.emit_state();
            }
            InternalEvent::DismissToast => {
                self.state.toast = None;
                self.emit_state();
            }

            _ => {
                warn!("unhandled internal event");
            }
        }
    }

    /// Increment rev, update shared state, and send update to native.
    pub(crate) fn emit_state(&mut self) {
        self.rev += 1;
        self.state.rev = self.rev;

        if let Ok(mut guard) = self.shared_state.write() {
            *guard = self.state.clone();
        }

        let _ = self.update_tx.send(AppUpdate::FullState {
            state: self.state.clone(),
        });
    }

    pub(crate) fn show_toast(&mut self, message: &str, is_error: bool) {
        self.state.toast = Some(Toast {
            message: message.to_string(),
            is_error,
        });
        self.emit_state();
    }
}
