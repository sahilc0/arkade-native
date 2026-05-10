use tracing::warn;

use super::AppCore;

impl AppCore {
    /// Enable Nostr backup.
    pub(crate) fn handle_enable_nostr_backup(&mut self) {
        // TODO: implement Nostr relay backup
        warn!("nostr backup not yet implemented");
        self.show_toast("Nostr backup not yet implemented", true);
    }

    /// Disable Nostr backup.
    pub(crate) fn handle_disable_nostr_backup(&mut self) {
        warn!("nostr backup not yet implemented");
        self.show_toast("Nostr backup not yet implemented", true);
    }
}
