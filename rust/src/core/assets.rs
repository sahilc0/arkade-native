use tracing::warn;

use super::AppCore;

impl AppCore {
    /// Assets are an application-layer feature on top of Ark VTXOs.
    /// The Rust SDK doesn't currently expose asset operations directly —
    /// they're handled via the TypeScript SDK's AssetManager.
    /// For now, these are stubs that will be implemented when
    /// asset support is added to the Rust SDK.

    pub(crate) fn handle_refresh_assets(&mut self) {
        warn!("asset operations not yet available in rust-sdk");
        self.state.assets = Some(crate::state::AssetsListState { assets: vec![] });
        self.emit_state();
    }

    pub(crate) fn handle_mint_asset(
        &mut self,
        _name: String,
        _ticker: String,
        _amount: u64,
        _decimals: u8,
    ) {
        self.show_toast("Asset minting not yet available in rust-sdk", true);
    }

    pub(crate) fn handle_burn_asset(&mut self, _asset_id: String, _amount: u64) {
        self.show_toast("Asset burning not yet available in rust-sdk", true);
    }

    pub(crate) fn handle_reissue_asset(&mut self, _asset_id: String, _amount: u64) {
        self.show_toast("Asset reissuing not yet available in rust-sdk", true);
    }

    pub(crate) fn handle_import_asset(&mut self, _asset_id: String) {
        self.show_toast("Asset importing not yet available in rust-sdk", true);
    }

    pub(crate) fn handle_transfer_asset(
        &mut self,
        _asset_id: String,
        _recipient: String,
        _amount: u64,
    ) {
        self.show_toast("Asset transfer not yet available in rust-sdk", true);
    }
}
