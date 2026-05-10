use serde::{Deserialize, Serialize};

#[derive(Debug, thiserror::Error)]
pub enum BoltzError {
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),

    #[error("API error: {message}")]
    Api { message: String },

    #[error("not implemented")]
    NotImplemented,
}

// ── Fee structures ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeesResponse {
    pub percentage: f64,
    pub miner_fees: MinerFees,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MinerFees {
    pub lockup: u64,
    pub claim: u64,
}

// ── Swap status ──

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwapStatusResponse {
    pub status: String,
    pub transaction: Option<SwapTransaction>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwapTransaction {
    pub id: String,
    pub hex: Option<String>,
}

// ── Submarine swap (ARK → Lightning) ──

#[derive(Debug, Clone, Serialize)]
pub struct CreateSubmarineRequest {
    pub invoice: String,
    pub refund_public_key: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SubmarineSwapResponse {
    pub id: String,
    pub address: String,
    pub expected_amount: u64,
    pub bip21: String,
    pub swap_tree: Option<serde_json::Value>,
}

// ── Reverse submarine swap (Lightning → ARK) ──

#[derive(Debug, Clone, Serialize)]
pub struct CreateReverseRequest {
    pub invoice_amount: u64,
    pub claim_public_key: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ReverseSwapResponse {
    pub id: String,
    pub invoice: String,
    pub lockup_address: String,
    pub swap_tree: Option<serde_json::Value>,
}

// ── Chain swap (ARK ↔ BTC) ──

#[derive(Debug, Clone, Serialize)]
pub struct CreateChainSwapRequest {
    pub user_lock_amount: Option<u64>,
    pub claim_public_key: String,
    pub refund_public_key: String,
    pub from: String,
    pub to: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ChainSwapResponse {
    pub id: String,
    pub lockup_details: ChainSwapDetails,
    pub claim_details: ChainSwapDetails,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ChainSwapDetails {
    pub address: String,
    pub amount: Option<u64>,
    pub swap_tree: Option<serde_json::Value>,
}
