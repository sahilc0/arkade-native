use clap::{Parser, Subcommand};

use arkade_core::actions::AppAction;
use arkade_core::updates::AppUpdate;
use arkade_core::FfiApp;

#[derive(Parser)]
#[command(name = "arkade", about = "Arkade wallet CLI")]
struct Cli {
    /// Network to use (mutinynet, bitcoin, signet)
    #[arg(long, default_value = "mutinynet")]
    network: String,

    /// Data directory for wallet storage
    #[arg(long)]
    data_dir: Option<String>,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new wallet
    Create {
        /// Wallet password
        #[arg(long, default_value = "")]
        password: String,
    },

    /// Restore wallet from mnemonic
    Restore {
        /// BIP39 mnemonic phrase
        #[arg(long)]
        mnemonic: String,
        /// Wallet password
        #[arg(long, default_value = "")]
        password: String,
    },

    /// Unlock an existing wallet
    Unlock {
        /// Wallet password
        #[arg(long, default_value = "")]
        password: String,
    },

    /// Show wallet balance
    Balance,

    /// Show transaction history
    History,

    /// Show wallet addresses
    Addresses,

    /// Show receiving address (Ark off-chain)
    Address,

    /// Show boarding address (on-chain deposit)
    BoardingAddress,

    /// Generate a Lightning invoice
    Invoice {
        /// Amount in satoshis
        amount_sats: u64,
    },

    /// Send to a recipient
    Send {
        /// Recipient (Ark address, BTC address, or Lightning invoice)
        recipient: String,
        /// Amount in satoshis
        amount_sats: u64,
    },

    /// Redeem an ArkNote
    RedeemNote {
        /// ArkNote string
        note: String,
    },

    /// Settle VTXOs into the next batch
    Settle {
        /// Specific VTXO outpoints to settle (optional)
        #[arg(long)]
        vtxos: Vec<String>,
    },

    /// Pay a Lightning invoice (submarine swap via Boltz)
    PayInvoice {
        /// Lightning invoice
        invoice: String,
    },

    /// Create a Lightning invoice (reverse swap via Boltz)
    CreateInvoice {
        /// Amount in satoshis
        amount_sats: u64,
    },

    /// Swap ARK to on-chain BTC
    ArkToBtc {
        /// Destination BTC address
        address: String,
        /// Amount in satoshis
        amount_sats: u64,
    },

    /// Swap on-chain BTC to ARK
    BtcToArk {
        /// Amount in satoshis
        amount_sats: u64,
    },

    /// List Boltz swap history
    SwapHistory,

    /// List all custom assets
    ListAssets,

    /// Mint a new asset
    MintAsset {
        #[arg(long)]
        name: String,
        #[arg(long)]
        ticker: String,
        #[arg(long)]
        amount: u64,
        #[arg(long, default_value = "8")]
        decimals: u8,
    },

    /// Burn an asset
    BurnAsset {
        #[arg(long)]
        asset_id: String,
        #[arg(long)]
        amount: u64,
    },

    /// Transfer an asset
    TransferAsset {
        #[arg(long)]
        asset_id: String,
        #[arg(long)]
        recipient: String,
        #[arg(long)]
        amount: u64,
    },

    /// List VTXOs
    ListVtxos,

    /// Show current configuration
    Config,
}

/// Simple reconciler that prints state updates.
struct CliReconciler;

impl arkade_core::AppReconciler for CliReconciler {
    fn reconcile(&self, update: AppUpdate) {
        match update {
            AppUpdate::FullState { state } => {
                // For CLI, we just track state changes silently
                // Commands will read state directly after dispatching
                let _ = state;
            }
            AppUpdate::WalletCreated { mnemonic } => {
                println!("\nWallet created! Save your mnemonic:\n");
                println!("  {}\n", mnemonic);
                println!("WARNING: Write this down and store it safely.");
                println!("You will need it to recover your wallet.\n");
            }
            AppUpdate::MnemonicRevealed { mnemonic } => {
                println!("\nYour mnemonic:\n  {}\n", mnemonic);
            }
            AppUpdate::CopyToClipboard { text } => {
                println!("Copied: {}", text);
            }
            AppUpdate::OpenUrl { url } => {
                println!("Open: {}", url);
            }
            AppUpdate::HapticFeedback { .. } => {}
        }
    }
}

fn main() {
    let cli = Cli::parse();

    let data_dir = cli.data_dir.unwrap_or_else(|| {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        format!("{}/.arkade", home)
    });

    // Ensure data directory exists
    std::fs::create_dir_all(&data_dir).expect("failed to create data directory");

    let app = FfiApp::new(data_dir, cli.network);
    app.listen_for_updates(Box::new(CliReconciler));

    // Give the actor a moment to initialize
    std::thread::sleep(std::time::Duration::from_millis(100));

    match cli.command {
        Commands::Create { password } => {
            app.dispatch(AppAction::CreateWallet { password });
            wait_for_connected(&app);
            let state = app.state();
            match &state.auth {
                arkade_core::state::AuthState::Connected { pubkey } => {
                    println!("Connected! Ark address: {}", pubkey);
                    if let Some(addrs) = &state.addresses {
                        if let Some(boarding) = &addrs.boarding_address {
                            println!("Boarding address: {}", boarding);
                        }
                    }
                }
                _ => {
                    if let Some(toast) = &state.toast {
                        eprintln!("Error: {}", toast.message);
                    }
                }
            }
        }
        Commands::Restore { mnemonic, password } => {
            app.dispatch(AppAction::RestoreWallet { mnemonic, password });
            wait_for_connected(&app);
            let state = app.state();
            match &state.auth {
                arkade_core::state::AuthState::Connected { pubkey } => {
                    println!("Restored and connected! Ark address: {}", pubkey);
                }
                _ => {
                    if let Some(toast) = &state.toast {
                        eprintln!("Error: {}", toast.message);
                    }
                }
            }
        }
        Commands::Unlock { password } => {
            app.dispatch(AppAction::UnlockWallet { password });
            wait_for_connected(&app);
            let state = app.state();
            match &state.auth {
                arkade_core::state::AuthState::Connected { pubkey } => {
                    println!("Unlocked! Ark address: {}", pubkey);
                }
                _ => {
                    if let Some(toast) = &state.toast {
                        eprintln!("Error: {}", toast.message);
                    }
                }
            }
        }
        Commands::Balance => {
            // Auto-unlock if wallet exists
            app.dispatch(AppAction::UnlockWallet { password: String::new() });
            wait_for_connected(&app);

            app.dispatch(AppAction::RefreshBalance);
            wait_for_result(&app);
            let state = app.state();
            if let Some(balance) = &state.balance {
                println!("Off-chain: {} sats (confirmed)", balance.offchain_confirmed_sats);
                println!("Off-chain: {} sats (pending)", balance.offchain_pending_sats);
                println!("On-chain:  {} sats (confirmed)", balance.onchain_confirmed_sats);
                println!("On-chain:  {} sats (pending)", balance.onchain_pending_sats);
                println!("───────────────────────────");
                println!("Total:     {} sats", balance.offchain_total_sats + balance.onchain_confirmed_sats);
            } else {
                println!("Wallet not connected. Run 'arkade create' or 'arkade unlock' first.");
            }
        }
        Commands::History => {
            app.dispatch(AppAction::UnlockWallet { password: String::new() });
            wait_for_connected(&app);
            app.dispatch(AppAction::RefreshTransactionHistory);
            wait_for_result(&app);
            let state = app.state();
            if state.transactions.is_empty() {
                println!("No transactions yet.");
            } else {
                for tx in &state.transactions {
                    let direction = if tx.amount_sats > 0 { "+" } else { "" };
                    let status = if tx.is_settled { "settled" } else { "pending" };
                    println!(
                        "{}{} sats  {:?}  [{}]  {}",
                        direction, tx.amount_sats, tx.tx_type, status, tx.display_time
                    );
                }
            }
        }
        Commands::Addresses | Commands::Address => {
            app.dispatch(AppAction::UnlockWallet { password: String::new() });
            wait_for_connected(&app);
            let state = app.state();
            if let Some(addrs) = &state.addresses {
                if let Some(addr) = &addrs.offchain_address {
                    println!("Ark address:     {}", addr);
                }
                if let Some(addr) = &addrs.boarding_address {
                    println!("Boarding address: {}", addr);
                }
            } else {
                println!("Wallet not connected.");
            }
        }
        Commands::BoardingAddress => {
            app.dispatch(AppAction::UnlockWallet { password: String::new() });
            wait_for_connected(&app);
            let state = app.state();
            if let Some(addrs) = &state.addresses {
                if let Some(addr) = &addrs.boarding_address {
                    println!("{}", addr);
                }
            } else {
                println!("Wallet not connected.");
            }
        }
        Commands::Invoice { amount_sats } => {
            app.dispatch(AppAction::GenerateLightningInvoice { amount_sats });
            wait_for_result(&app);
            // Invoice will be printed via reconciler or state
        }
        Commands::Send { recipient, amount_sats } => {
            app.dispatch(AppAction::ParseRecipient { input: recipient });
            wait_for_result(&app);
            app.dispatch(AppAction::SetSendAmount { sats: amount_sats });
            app.dispatch(AppAction::ConfirmSend);
            wait_for_result(&app);
            let state = app.state();
            if let Some(toast) = &state.toast {
                if toast.is_error {
                    eprintln!("Error: {}", toast.message);
                } else {
                    println!("{}", toast.message);
                }
            }
        }
        Commands::RedeemNote { note } => {
            app.dispatch(AppAction::ParseArkNote { input: note });
            wait_for_result(&app);
            app.dispatch(AppAction::ConfirmRedeemArkNote);
            wait_for_result(&app);
        }
        Commands::Settle { vtxos } => {
            if vtxos.is_empty() {
                app.dispatch(AppAction::Settle);
            } else {
                app.dispatch(AppAction::SettleVtxos { outpoints: vtxos });
            }
            wait_for_result(&app);
        }
        Commands::PayInvoice { invoice } => {
            app.dispatch(AppAction::CreateSubmarineSwap { invoice });
            wait_for_result(&app);
        }
        Commands::CreateInvoice { amount_sats } => {
            app.dispatch(AppAction::UnlockWallet { password: String::new() });
            wait_for_connected(&app);
            app.dispatch(AppAction::CreateReverseSwap { amount_sats });
            // Wait longer for the Boltz API call
            wait_for_condition(&app, |s| {
                s.receive_flow.is_some() || s.toast.as_ref().is_some_and(|t| t.is_error)
            }, 15000);
            let state = app.state();
            if let Some(flow) = &state.receive_flow {
                if flow.error.is_none() {
                    println!("{}", flow.address_or_invoice);
                } else {
                    eprintln!("Error: {}", flow.error.as_deref().unwrap_or("unknown"));
                }
            } else if let Some(toast) = &state.toast {
                eprintln!("Error: {}", toast.message);
            }
        }
        Commands::ArkToBtc { address, amount_sats } => {
            app.dispatch(AppAction::CreateArkToBtcSwap { address, amount_sats });
            wait_for_result(&app);
        }
        Commands::BtcToArk { amount_sats } => {
            app.dispatch(AppAction::CreateBtcToArkSwap { amount_sats });
            wait_for_result(&app);
        }
        Commands::SwapHistory => {
            app.dispatch(AppAction::RefreshSwapHistory);
            wait_for_result(&app);
            let state = app.state();
            if let Some(boltz) = &state.boltz {
                if boltz.swaps.is_empty() {
                    println!("No swaps yet.");
                } else {
                    for swap in &boltz.swaps {
                        println!(
                            "{} {:?} {} sats [{:?}]",
                            swap.id, swap.swap_type, swap.amount_sats, swap.status
                        );
                    }
                }
            }
        }
        Commands::ListAssets => {
            app.dispatch(AppAction::RefreshAssets);
            wait_for_result(&app);
            let state = app.state();
            if let Some(assets) = &state.assets {
                if assets.assets.is_empty() {
                    println!("No assets.");
                } else {
                    for asset in &assets.assets {
                        println!(
                            "{} ({}) — {} {}",
                            asset.name, asset.ticker, asset.balance, asset.asset_id
                        );
                    }
                }
            }
        }
        Commands::MintAsset { name, ticker, amount, decimals } => {
            app.dispatch(AppAction::MintAsset { name, ticker, amount, decimals });
            wait_for_result(&app);
        }
        Commands::BurnAsset { asset_id, amount } => {
            app.dispatch(AppAction::BurnAsset { asset_id, amount });
            wait_for_result(&app);
        }
        Commands::TransferAsset { asset_id, recipient, amount } => {
            app.dispatch(AppAction::TransferAsset { asset_id, recipient, amount });
            wait_for_result(&app);
        }
        Commands::ListVtxos => {
            app.dispatch(AppAction::LoadVtxos);
            wait_for_result(&app);
            let state = app.state();
            if let Some(vtxos) = &state.vtxo_management {
                println!("Total: {} sats across {} VTXOs", vtxos.total_sats, vtxos.vtxos.len());
                for vtxo in &vtxos.vtxos {
                    println!(
                        "  {} — {} sats [{:?}] expires {}",
                        vtxo.outpoint, vtxo.amount_sats, vtxo.status, vtxo.expiry_display
                    );
                }
            }
        }
        Commands::Config => {
            let state = app.state();
            println!("Theme:    {:?}", state.config.theme);
            println!("Unit:     {:?}", state.config.display_unit);
            println!("Fiat:     {:?}", state.config.fiat_currency);
            println!("Display:  {:?}", state.config.currency_display);
            println!("Haptics:  {}", state.config.haptics_enabled);
            println!("Notifs:   {}", state.config.notifications_enabled);
            println!("Balance:  {}", state.config.show_balance);
        }
    }
}

fn wait_for_result(app: &FfiApp) {
    wait_for_condition(app, |_| true, 5000);
}

/// Wait for the wallet to be connected (auth state = Connected).
fn wait_for_connected(app: &FfiApp) {
    wait_for_condition(
        app,
        |s| matches!(s.auth, arkade_core::state::AuthState::Connected { .. })
            || s.toast.as_ref().is_some_and(|t| t.is_error),
        30000,
    );
}

/// Poll state until condition is met or timeout.
fn wait_for_condition(app: &FfiApp, predicate: impl Fn(&arkade_core::state::AppState) -> bool, timeout_ms: u64) {
    let start = std::time::Instant::now();
    loop {
        let state = app.state();
        if predicate(&state) {
            break;
        }
        if start.elapsed().as_millis() as u64 > timeout_ms {
            break;
        }
        std::thread::sleep(std::time::Duration::from_millis(100));
    }
}
