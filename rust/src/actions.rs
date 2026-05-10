use crate::state::*;

/// Every action the app can dispatch. Fire-and-forget — never blocks.
#[derive(uniffi::Enum, Debug, Clone)]
pub enum AppAction {
    // ── Navigation ──
    PushScreen {
        screen: Screen,
    },
    PopScreen,
    ReplaceScreen {
        screen: Screen,
    },

    // ── Lifecycle ──
    Foregrounded,
    Backgrounded,
    ClearToast,

    // ── Onboarding ──
    CreateWallet {
        password: String,
    },
    RestoreWallet {
        mnemonic: String,
        password: String,
    },
    UnlockWallet {
        password: String,
    },
    UnlockWithBiometrics,

    // ── Wallet ──
    RefreshBalance,
    RefreshTransactionHistory,
    RefreshAll,

    // ── Send ──
    ParseRecipient {
        input: String,
    },
    SetSendAmount {
        sats: u64,
    },
    EstimateSendFee,
    ConfirmSend,
    CancelSend,

    // ── Receive ──
    SetReceiveType {
        receive_type: ReceiveType,
    },
    SetReceiveAmount {
        sats: u64,
    },
    GenerateReceiveAddress,
    GenerateLightningInvoice {
        amount_sats: u64,
    },

    // ── ArkNotes ──
    ParseArkNote {
        input: String,
    },
    ConfirmRedeemArkNote,
    CancelArkNoteRedeem,

    // ── Settle / Batch ──
    Settle,
    SettleVtxos {
        outpoints: Vec<String>,
    },

    // ── Boltz Swaps ──
    ConnectBoltz,
    DisconnectBoltz,
    CreateSubmarineSwap {
        invoice: String,
    },
    CreateReverseSwap {
        amount_sats: u64,
    },
    CreateArkToBtcSwap {
        address: String,
        amount_sats: u64,
    },
    CreateBtcToArkSwap {
        amount_sats: u64,
    },
    ClaimSwap {
        swap_id: String,
    },
    RefundSwap {
        swap_id: String,
    },
    RefreshSwapHistory,

    // ── Custom Assets ──
    RefreshAssets,
    MintAsset {
        name: String,
        ticker: String,
        amount: u64,
        decimals: u8,
    },
    BurnAsset {
        asset_id: String,
        amount: u64,
    },
    ReissueAsset {
        asset_id: String,
        amount: u64,
    },
    ImportAsset {
        asset_id: String,
    },
    RemoveImportedAsset {
        asset_id: String,
    },
    TransferAsset {
        asset_id: String,
        recipient: String,
        amount: u64,
    },

    // ── Partner Apps ──
    LoadPartnerApp {
        app: PartnerAppKind,
    },
    ClearPartnerApp,

    // ── Settings ──
    SetTheme {
        theme: Theme,
    },
    SetDisplayUnit {
        unit: DisplayUnit,
    },
    SetFiatCurrency {
        currency: FiatCurrency,
    },
    SetCurrencyDisplay {
        display: CurrencyDisplay,
    },
    SetHaptics {
        enabled: bool,
    },
    SetNotifications {
        enabled: bool,
    },
    SetShowBalance {
        show: bool,
    },
    ChangePassword {
        old_password: String,
        new_password: String,
    },
    SetAspUrl {
        url: String,
    },

    // ── Delegates ──
    SetDelegateEnabled {
        enabled: bool,
    },
    AddDelegate {
        name: String,
        url: String,
    },
    RemoveDelegate {
        index: u32,
    },

    // ── Backup ──
    RevealMnemonic {
        password: String,
    },
    EnableNostrBackup,
    DisableNostrBackup,

    // ── VTXO Management ──
    LoadVtxos,
    ToggleVtxoSelection {
        outpoint: String,
    },
    SettleSelectedVtxos,

    // ── Reset ──
    ResetWallet,
}
