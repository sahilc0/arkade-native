pub mod actions;
pub mod state;
pub mod updates;
pub mod core;
pub mod logging;

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, RwLock};
use std::thread;

use flume::{Receiver, Sender};
use tracing::info;

use actions::AppAction;
use state::AppState;
use updates::{AppUpdate, CoreMsg};

uniffi::setup_scaffolding!();

// ── Error type for UniFFI ──

#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum AppError {
    #[error("{message}")]
    General { message: String },
}

// ── Callback Interfaces ──

/// Primary state update reconciler — native platforms implement this.
#[uniffi::export(callback_interface)]
pub trait AppReconciler: Send + Sync {
    fn reconcile(&self, update: AppUpdate);
}

// ── FfiApp ──

/// The main entry point for native platforms.
/// Created once at app startup, lives for the app's lifetime.
#[derive(uniffi::Object)]
pub struct FfiApp {
    core_tx: Sender<CoreMsg>,
    update_rx: Receiver<AppUpdate>,
    listening: AtomicBool,
    shared_state: Arc<RwLock<AppState>>,
}

#[uniffi::export]
impl FfiApp {
    /// Create a new FfiApp instance.
    /// - `data_dir`: Platform-specific app data directory
    /// - `network`: "mutinynet", "bitcoin", or "signet"
    #[uniffi::constructor]
    pub fn new(
        data_dir: String,
        network: String,
    ) -> Arc<Self> {
        // Install TLS crypto provider before anything else
        let _ = rustls::crypto::ring::default_provider().install_default();

        logging::init_logging();
        info!("FfiApp::new(data_dir={}, network={})", data_dir, network);

        let shared_state = Arc::new(RwLock::new(AppState::default()));
        let (core_tx, core_rx) = flume::unbounded::<CoreMsg>();
        let (update_tx, update_rx) = flume::unbounded::<AppUpdate>();

        let shared_state_clone = shared_state.clone();
        let core_tx_clone = core_tx.clone();
        let data_dir_clone = data_dir.clone();
        let network_clone = network.clone();

        // Spawn actor thread
        thread::Builder::new()
            .name("arkade-core".to_string())
            .spawn(move || {
                let mut app_core = core::AppCore::new(
                    update_tx,
                    core_tx_clone,
                    shared_state_clone,
                    data_dir_clone,
                    network_clone,
                );

                while let Ok(msg) = core_rx.recv() {
                    app_core.handle_message(msg);
                }

                info!("actor loop exited");
            })
            .expect("failed to spawn actor thread");

        Arc::new(Self {
            core_tx,
            update_rx,
            listening: AtomicBool::new(false),
            shared_state,
        })
    }

    /// Get the current state synchronously (for initial render).
    pub fn state(&self) -> AppState {
        self.shared_state
            .read()
            .map(|s| s.clone())
            .unwrap_or_default()
    }

    /// Dispatch an action to the core. Fire-and-forget, never blocks.
    pub fn dispatch(&self, action: AppAction) {
        let _ = self.core_tx.send(CoreMsg::Action(action));
    }

    /// Start listening for state updates. Calls reconciler.reconcile() on a
    /// background thread — the reconciler must dispatch to the main thread.
    /// Only one listener at a time.
    pub fn listen_for_updates(&self, reconciler: Box<dyn AppReconciler>) {
        if self.listening.swap(true, Ordering::SeqCst) {
            return; // Already listening
        }

        let update_rx = self.update_rx.clone();

        thread::Builder::new()
            .name("arkade-reconciler".to_string())
            .spawn(move || {
                while let Ok(update) = update_rx.recv() {
                    reconciler.reconcile(update);
                }
            })
            .expect("failed to spawn reconciler thread");
    }
}
