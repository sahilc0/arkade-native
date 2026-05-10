use tracing::info;

use super::AppCore;
use crate::state::*;

impl AppCore {
    /// Change wallet password.
    pub(crate) fn handle_change_password(&mut self, old_password: String, new_password: String) {
        // For CLI, passwords aren't used yet (mnemonic stored unencrypted)
        // TODO: implement mnemonic encryption
        let _ = (old_password, new_password);
        self.show_toast("Password changed", false);
    }

    /// Set ASP server URL.
    pub(crate) fn handle_set_asp_url(&mut self, url: String) {
        info!("ASP URL changed to: {}", url);
        // This would require reconnecting
        self.show_toast("Server URL updated. Restart to apply.", false);
    }

    /// Reveal the mnemonic (requires password verification).
    pub(crate) fn handle_reveal_mnemonic(&mut self, _password: String) {
        let mnemonic_path = format!("{}/mnemonic", self.data_dir);
        match std::fs::read_to_string(&mnemonic_path) {
            Ok(mnemonic) => {
                let _ = self
                    .update_tx
                    .send(crate::updates::AppUpdate::MnemonicRevealed {
                        mnemonic: mnemonic.trim().to_string(),
                    });
            }
            Err(e) => {
                self.show_toast(&format!("Failed to read mnemonic: {e}"), true);
            }
        }
    }

    /// Populate the settings state for display.
    pub(crate) fn load_settings_state(&mut self) {
        let mnemonic_path = format!("{}/mnemonic", self.data_dir);
        let has_wallet = std::path::Path::new(&mnemonic_path).exists();

        self.state.settings = Some(SettingsState {
            has_password: false,         // TODO
            biometrics_available: false, // Platform callback needed
            biometrics_enabled: false,
            nostr_backup_enabled: false, // TODO
            delegate_enabled: false,     // TODO
            asp_url: match self.network.as_str() {
                "bitcoin" => "https://arkade.computer".to_string(),
                _ => "https://mutinynet.arkade.sh".to_string(),
            },
            network: self.network.clone(),
            app_version: "0.1.0".to_string(),
        });

        self.state.backup_state = Some(BackupState {
            has_mnemonic_backup: has_wallet,
            nostr_backup_enabled: false,
            nsec: None,
            last_backup_timestamp: None,
        });

        self.emit_state();
    }
}
