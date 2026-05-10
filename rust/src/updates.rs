use crate::state::AppState;

/// Updates sent from Rust core to native platforms.
#[derive(uniffi::Enum, Clone, Debug)]
pub enum AppUpdate {
    /// Full state snapshot — the primary update type.
    FullState { state: AppState },

    /// Wallet created — native should store the mnemonic in keychain.
    WalletCreated { mnemonic: String },

    /// Mnemonic revealed for backup — native displays then discards.
    MnemonicRevealed { mnemonic: String },

    /// Request native to copy text to clipboard.
    CopyToClipboard { text: String },

    /// Request native to open a URL.
    OpenUrl { url: String },

    /// Request haptic feedback from the platform.
    HapticFeedback { feedback_type: HapticType },
}

#[derive(uniffi::Enum, Clone, Debug, PartialEq)]
pub enum HapticType {
    Light,
    Medium,
    Heavy,
    Success,
    Warning,
    Error,
}

// ── Internal message types (not exposed via UniFFI) ──

/// Messages processed by the actor loop.
#[allow(dead_code)]
pub(crate) enum CoreMsg {
    /// User-dispatched action from the UI.
    Action(crate::actions::AppAction),
    /// Internal event from async tasks.
    Internal(Box<InternalEvent>),
}

/// Results from async operations, posted back to the actor loop.
#[allow(dead_code)]
pub(crate) enum InternalEvent {
    // Ark SDK results
    Connected {
        pubkey: String,
    },
    ConnectionFailed {
        error: String,
    },
    BalanceFetched {
        offchain_confirmed: u64,
        offchain_pending: u64,
        onchain_confirmed: u64,
        onchain_pending: u64,
    },
    BalanceFetchFailed {
        error: String,
    },
    TransactionsFetched {
        transactions: Vec<crate::state::TransactionItem>,
    },
    AddressesFetched {
        offchain: String,
        boarding: String,
        onchain: Option<String>,
    },

    // Send results
    RecipientParsed {
        recipient_type: crate::state::RecipientType,
        display: String,
    },
    FeeEstimated {
        fee_sats: u64,
    },
    SendCompleted {
        txid: String,
    },
    SendFailed {
        error: String,
    },

    // Receive results
    ReceiveAddressGenerated {
        address: String,
        qr_data: String,
    },
    LightningInvoiceGenerated {
        invoice: String,
        qr_data: String,
    },
    ReceiveGenerationFailed {
        error: String,
    },

    // Settle results
    SettleCompleted {
        txid: Option<String>,
    },
    SettleFailed {
        error: String,
    },

    // ArkNote results
    ArkNoteParsed {
        amount_sats: u64,
    },
    ArkNoteRedeemed {
        amount_sats: u64,
    },
    ArkNoteFailed {
        error: String,
    },

    // Boltz swap results
    SwapCreated {
        swap: crate::state::SwapSummary,
    },
    SwapStatusUpdated {
        swap_id: String,
        status: crate::state::SwapStatus,
    },
    SwapsFetched {
        swaps: Vec<crate::state::SwapSummary>,
    },
    SwapFailed {
        error: String,
    },

    // Asset results
    AssetsFetched {
        assets: Vec<crate::state::AssetSummary>,
    },
    AssetOperationCompleted {
        asset_id: String,
    },
    AssetOperationFailed {
        error: String,
    },

    // VTXO results
    VtxosFetched {
        vtxos: Vec<crate::state::VtxoItem>,
        total_sats: u64,
    },

    // Wallet lifecycle
    WalletInitialized {
        mnemonic: String,
        pubkey: String,
    },
    WalletRestored {
        pubkey: String,
    },
    WalletInitFailed {
        error: String,
    },
    ArkClientReady {
        client: Box<crate::core::onboarding::ArkClient>,
    },

    // Mnemonic
    MnemonicLoaded {
        mnemonic: String,
    },

    // Background ticks
    BalanceRefreshTick,
    SwapMonitorTick,

    // Fiat
    FiatPriceFetched {
        btc_price_usd: f64,
    },

    // Toast
    ShowToast {
        message: String,
        is_error: bool,
    },
    DismissToast,
}
