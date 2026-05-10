pub mod types;
pub mod submarine;
pub mod reverse;
pub mod chain;
pub mod monitor;

use reqwest::Client as HttpClient;
use types::*;

/// Client for the Boltz swap API.
pub struct BoltzClient {
    #[allow(dead_code)]
    http: HttpClient,
    base_url: String,
}

impl BoltzClient {
    pub fn new(base_url: &str) -> Self {
        Self {
            http: HttpClient::new(),
            base_url: base_url.trim_end_matches('/').to_string(),
        }
    }

    /// Get the base URL for the Boltz API.
    pub fn base_url(&self) -> &str {
        &self.base_url
    }

    /// Get fee structure for all swap types.
    pub async fn get_fees(&self) -> Result<FeesResponse, BoltzError> {
        let _url = format!("{}/v2/swap/submarine", self.base_url);
        // TODO: implement actual API call
        Err(BoltzError::NotImplemented)
    }

    /// Check swap status by ID.
    pub async fn get_swap_status(&self, id: &str) -> Result<SwapStatusResponse, BoltzError> {
        let _url = format!("{}/v2/swap/{}", self.base_url, id);
        // TODO: implement actual API call
        Err(BoltzError::NotImplemented)
    }
}

/// Default Boltz API URLs by network.
pub fn boltz_url_for_network(network: &str) -> &'static str {
    match network {
        "bitcoin" => "https://api.ark.boltz.exchange",
        "mutinynet" => "https://api.boltz.mutinynet.arkade.sh",
        "signet" => "https://boltz.signet.arkade.sh",
        _ => "https://api.boltz.mutinynet.arkade.sh",
    }
}
