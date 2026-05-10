/// Full application state snapshot. Sent to native platforms on every change.
/// Screen-specific sub-states are Option<T> — nil when not on that screen.

// ── Router ──

#[derive(uniffi::Record, Clone, Debug, Default)]
pub struct Router {
    pub screen_stack: Vec<Screen>,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum Screen {
    // Onboarding
    Loading,
    Init,
    CreateWallet,
    RestoreWallet,
    SetPassword,
    Connecting,
    OnboardingSuccess,
    Unlock,

    // Wallet core
    Home,
    SendForm,
    SendDetails,
    SendSuccess,
    ReceiveAmount,
    ReceiveQrCode,
    ReceiveSuccess,
    TransactionDetail { txid: String },

    // ArkNotes
    NoteForm,
    NoteRedeem,
    NoteSuccess,

    // Apps hub
    Apps,

    // Boltz
    BoltzIndex,
    BoltzSwap { swap_id: String },
    BoltzSettings,

    // Assets
    AssetsIndex,
    AssetDetail { asset_id: String },
    AssetMint,
    AssetMintSuccess,
    AssetBurn { asset_id: String },
    AssetReissue { asset_id: String },
    AssetImport,
    AssetSettings,

    // Settings
    SettingsMenu,
    SettingsGeneral,
    SettingsTheme,
    SettingsDisplay,
    SettingsFiat,
    SettingsHaptics,
    SettingsNotifications,
    SettingsPassword,
    SettingsBackup,
    SettingsLock,
    SettingsAdvanced,
    SettingsVtxos,
    SettingsDelegates,
    SettingsAbout,
    SettingsSupport,
    SettingsLogs,
    SettingsReset,

    // Error states
    Unavailable { reason: String },
}

impl Default for Screen {
    fn default() -> Self {
        Screen::Loading
    }
}

// ── Auth ──

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum AuthState {
    Unauthenticated,
    Locked,
    Connecting,
    Connected { pubkey: String },
}

impl Default for AuthState {
    fn default() -> Self {
        AuthState::Unauthenticated
    }
}

// ── Busy flags ──

#[derive(uniffi::Record, Clone, Debug, Default)]
pub struct BusyState {
    pub creating_wallet: bool,
    pub restoring_wallet: bool,
    pub connecting: bool,
    pub refreshing_balance: bool,
    pub sending: bool,
    pub settling: bool,
    pub generating_address: bool,
    pub creating_swap: bool,
}

// ── Toast ──

#[derive(uniffi::Record, Clone, Debug)]
pub struct Toast {
    pub message: String,
    pub is_error: bool,
}

// ── Balance ──

#[derive(uniffi::Record, Clone, Debug, Default)]
pub struct BalanceState {
    pub offchain_confirmed_sats: u64,
    pub offchain_pending_sats: u64,
    pub offchain_total_sats: u64,
    pub onchain_confirmed_sats: u64,
    pub onchain_pending_sats: u64,
    pub fiat_value: Option<String>,
    pub next_rollover_timestamp: Option<i64>,
}

// ── Transactions ──

#[derive(uniffi::Record, Clone, Debug)]
pub struct TransactionItem {
    pub txid: String,
    pub tx_type: TransactionType,
    pub amount_sats: i64,
    pub is_settled: bool,
    pub timestamp: Option<i64>,
    pub display_time: String,
    pub asset_id: Option<String>,
    pub asset_ticker: Option<String>,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum TransactionType {
    Boarding,
    Commitment,
    Ark,
    Offboard,
    SubmarineSwap,
    ReverseSwap,
    ChainSwap,
    AssetMint,
    AssetBurn,
    AssetTransfer,
}

// ── Transaction Detail ──

#[derive(uniffi::Record, Clone, Debug)]
pub struct TransactionDetailState {
    pub txid: String,
    pub tx_type: TransactionType,
    pub amount_sats: i64,
    pub fee_sats: Option<u64>,
    pub is_settled: bool,
    pub created_at: Option<i64>,
    pub settled_at: Option<i64>,
    pub recipient: Option<String>,
    pub sender: Option<String>,
    pub boarding_txid: Option<String>,
    pub round_txid: Option<String>,
    pub redeem_txid: Option<String>,
    pub asset_id: Option<String>,
    pub asset_name: Option<String>,
    pub can_settle: bool,
    pub inputs_to_settle: Vec<String>,
}

// ── Addresses ──

#[derive(uniffi::Record, Clone, Debug, Default)]
pub struct AddressesState {
    pub offchain_address: Option<String>,
    pub boarding_address: Option<String>,
    pub onchain_address: Option<String>,
}

// ── Send Flow ──

#[derive(uniffi::Record, Clone, Debug)]
pub struct SendFlowState {
    pub recipient: String,
    pub recipient_type: RecipientType,
    pub amount_sats: Option<u64>,
    pub estimated_fee_sats: Option<u64>,
    pub max_sendable_sats: u64,
    pub is_sending: bool,
    pub error: Option<String>,
    pub confirmation: Option<SendConfirmation>,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum RecipientType {
    ArkAddress,
    BitcoinAddress,
    LightningInvoice,
    LnUrl,
    Bip21,
    ArkNote,
    Unknown,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct SendConfirmation {
    pub recipient_display: String,
    pub amount_sats: u64,
    pub fee_sats: u64,
    pub total_sats: u64,
    pub is_swap: bool,
}

// ── Receive Flow ──

#[derive(uniffi::Record, Clone, Debug)]
pub struct ReceiveFlowState {
    pub receive_type: ReceiveType,
    pub address_or_invoice: String,
    pub amount_sats: Option<u64>,
    pub qr_data: String,
    pub is_generating: bool,
    pub error: Option<String>,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum ReceiveType {
    ArkAddress,
    BoardingAddress,
    LightningInvoice,
}

// ── ArkNote Flow ──

#[derive(uniffi::Record, Clone, Debug)]
pub struct ArkNoteFlowState {
    pub note_input: String,
    pub parsed_amount_sats: Option<u64>,
    pub is_redeeming: bool,
    pub error: Option<String>,
    pub redeemed_amount_sats: Option<u64>,
}

// ── Boltz Swaps ──

#[derive(uniffi::Record, Clone, Debug, Default)]
pub struct BoltzState {
    pub is_connected: bool,
    pub swaps: Vec<SwapSummary>,
    pub submarine_fee_percent: Option<f64>,
    pub reverse_fee_percent: Option<f64>,
    pub chain_fee_percent: Option<f64>,
    pub min_swap_sats: Option<u64>,
    pub max_swap_sats: Option<u64>,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct SwapSummary {
    pub id: String,
    pub swap_type: SwapType,
    pub status: SwapStatus,
    pub amount_sats: u64,
    pub created_at: i64,
    pub is_claimable: bool,
    pub is_refundable: bool,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum SwapType {
    Submarine,
    ReverseSubmarine,
    ArkToBtcChain,
    BtcToArkChain,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum SwapStatus {
    Created,
    Pending,
    Completed,
    Failed,
    Refunded,
    Expired,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct SwapDetailState {
    pub id: String,
    pub swap_type: SwapType,
    pub status: SwapStatus,
    pub amount_sats: u64,
    pub fee_sats: u64,
    pub created_at: i64,
    pub address_or_invoice: String,
    pub txid: Option<String>,
    pub is_claimable: bool,
    pub is_refundable: bool,
    pub error: Option<String>,
}

// ── Custom Assets ──

#[derive(uniffi::Record, Clone, Debug, Default)]
pub struct AssetsListState {
    pub assets: Vec<AssetSummary>,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct AssetSummary {
    pub asset_id: String,
    pub name: String,
    pub ticker: String,
    pub balance: u64,
    pub decimals: u8,
    pub icon_url: Option<String>,
    pub is_imported: bool,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct AssetDetailState {
    pub asset_id: String,
    pub name: String,
    pub ticker: String,
    pub balance: u64,
    pub decimals: u8,
    pub supply: u64,
    pub icon_url: Option<String>,
    pub can_mint: bool,
    pub can_burn: bool,
    pub can_reissue: bool,
    pub control_asset_id: Option<String>,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct AssetFlowState {
    pub flow_type: AssetFlowType,
    pub asset_id: Option<String>,
    pub name: String,
    pub ticker: String,
    pub amount: Option<u64>,
    pub decimals: u8,
    pub recipient: Option<String>,
    pub is_processing: bool,
    pub error: Option<String>,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum AssetFlowType {
    Mint,
    Burn,
    Reissue,
    Import,
    Transfer,
}

// ── Partner Apps ──

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum PartnerAppKind {
    Dfx,
    Lendasat,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct PartnerAppState {
    pub app: PartnerAppKind,
    pub url: Option<String>,
    pub is_loading: bool,
    pub error: Option<String>,
}

// ── Settings ──

#[derive(uniffi::Record, Clone, Debug)]
pub struct SettingsState {
    pub has_password: bool,
    pub biometrics_available: bool,
    pub biometrics_enabled: bool,
    pub nostr_backup_enabled: bool,
    pub delegate_enabled: bool,
    pub asp_url: String,
    pub network: String,
    pub app_version: String,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct VtxoManagementState {
    pub vtxos: Vec<VtxoItem>,
    pub total_sats: u64,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct VtxoItem {
    pub outpoint: String,
    pub amount_sats: u64,
    pub status: VtxoStatus,
    pub expiry_display: String,
    pub is_selected: bool,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum VtxoStatus {
    Confirmed,
    PreConfirmed,
    Recoverable,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct DelegateManagementState {
    pub delegates: Vec<DelegateItem>,
    pub is_enabled: bool,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct DelegateItem {
    pub name: String,
    pub url: String,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct BackupState {
    pub has_mnemonic_backup: bool,
    pub nostr_backup_enabled: bool,
    pub nsec: Option<String>,
    pub last_backup_timestamp: Option<i64>,
}

#[derive(uniffi::Record, Clone, Debug)]
pub struct LogEntry {
    pub timestamp: i64,
    pub level: String,
    pub message: String,
}

// ── Config (persisted preferences) ──

#[derive(uniffi::Record, Clone, Debug)]
pub struct AppConfig {
    pub theme: Theme,
    pub display_unit: DisplayUnit,
    pub fiat_currency: FiatCurrency,
    pub currency_display: CurrencyDisplay,
    pub haptics_enabled: bool,
    pub notifications_enabled: bool,
    pub show_balance: bool,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            theme: Theme::System,
            display_unit: DisplayUnit::Sats,
            fiat_currency: FiatCurrency::Usd,
            currency_display: CurrencyDisplay::FiatOnly,
            haptics_enabled: true,
            notifications_enabled: true,
            show_balance: true,
        }
    }
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum Theme {
    Light,
    Dark,
    System,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum DisplayUnit {
    Sats,
    Btc,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum FiatCurrency {
    Usd,
    Eur,
    Chf,
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum CurrencyDisplay {
    SatsOnly,
    FiatOnly,
    Both,
}

// ── Top-level AppState ──

#[derive(uniffi::Record, Clone, Debug)]
pub struct AppState {
    pub rev: u64,
    pub router: Router,
    pub auth: AuthState,
    pub busy: BusyState,
    pub toast: Option<Toast>,

    // Core wallet (loaded when authenticated)
    pub balance: Option<BalanceState>,
    pub transactions: Vec<TransactionItem>,
    pub addresses: Option<AddressesState>,

    // Screen-specific (populated on navigation)
    pub send_flow: Option<SendFlowState>,
    pub receive_flow: Option<ReceiveFlowState>,
    pub arknote_flow: Option<ArkNoteFlowState>,
    pub transaction_detail: Option<TransactionDetailState>,

    // Boltz
    pub boltz: Option<BoltzState>,
    pub swap_detail: Option<SwapDetailState>,

    // Assets
    pub assets: Option<AssetsListState>,
    pub asset_detail: Option<AssetDetailState>,
    pub asset_flow: Option<AssetFlowState>,

    // Partner apps
    pub partner_app: Option<PartnerAppState>,

    // Settings
    pub settings: Option<SettingsState>,
    pub vtxo_management: Option<VtxoManagementState>,
    pub delegate_management: Option<DelegateManagementState>,
    pub backup_state: Option<BackupState>,
    pub logs: Vec<LogEntry>,

    // Persisted config
    pub config: AppConfig,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            rev: 0,
            router: Router {
                screen_stack: vec![Screen::Loading],
            },
            auth: AuthState::default(),
            busy: BusyState::default(),
            toast: None,
            balance: None,
            transactions: vec![],
            addresses: None,
            send_flow: None,
            receive_flow: None,
            arknote_flow: None,
            transaction_detail: None,
            boltz: None,
            swap_detail: None,
            assets: None,
            asset_detail: None,
            asset_flow: None,
            partner_app: None,
            settings: None,
            vtxo_management: None,
            delegate_management: None,
            backup_state: None,
            logs: vec![],
            config: AppConfig::default(),
        }
    }
}
