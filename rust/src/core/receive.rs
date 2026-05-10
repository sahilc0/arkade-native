use tracing::{error, info};

use super::AppCore;
use crate::state::*;

impl AppCore {
    /// Generate a receive address and populate the receive flow state.
    pub(crate) fn handle_generate_receive_address(&mut self) {
        if self.ark_client.is_none() {
            self.show_toast("Wallet not connected", true);
            return;
        }

        let receive_type = self
            .state
            .receive_flow
            .as_ref()
            .map(|f| f.receive_type.clone())
            .unwrap_or(ReceiveType::ArkAddress);

        self.state.busy.generating_address = true;
        self.emit_state();

        let client = self.ark_client.as_ref().unwrap();

        match receive_type {
            ReceiveType::ArkAddress => match client.get_offchain_address() {
                Ok((addr, _)) => {
                    let encoded = addr.encode();
                    info!("generated ark address: {}", encoded);
                    self.state.receive_flow = Some(ReceiveFlowState {
                        receive_type: ReceiveType::ArkAddress,
                        address_or_invoice: encoded.clone(),
                        amount_sats: self.state.receive_flow.as_ref().and_then(|f| f.amount_sats),
                        qr_data: encoded,
                        is_generating: false,
                        error: None,
                    });
                }
                Err(e) => {
                    error!("failed to get ark address: {e}");
                    self.state.receive_flow = Some(ReceiveFlowState {
                        receive_type: ReceiveType::ArkAddress,
                        address_or_invoice: String::new(),
                        amount_sats: None,
                        qr_data: String::new(),
                        is_generating: false,
                        error: Some(format!("{e}")),
                    });
                }
            },
            ReceiveType::BoardingAddress => match client.get_boarding_address() {
                Ok(addr) => {
                    let addr_str = addr.to_string();
                    info!("generated boarding address: {}", addr_str);
                    self.state.receive_flow = Some(ReceiveFlowState {
                        receive_type: ReceiveType::BoardingAddress,
                        address_or_invoice: addr_str.clone(),
                        amount_sats: self.state.receive_flow.as_ref().and_then(|f| f.amount_sats),
                        qr_data: addr_str,
                        is_generating: false,
                        error: None,
                    });
                }
                Err(e) => {
                    error!("failed to get boarding address: {e}");
                    self.state.receive_flow = Some(ReceiveFlowState {
                        receive_type: ReceiveType::BoardingAddress,
                        address_or_invoice: String::new(),
                        amount_sats: None,
                        qr_data: String::new(),
                        is_generating: false,
                        error: Some(format!("{e}")),
                    });
                }
            },
            ReceiveType::LightningInvoice => {
                let amount_sats = self.state.receive_flow.as_ref().and_then(|f| f.amount_sats);

                match amount_sats {
                    Some(sats) if sats > 0 => {
                        // Use Boltz reverse swap to generate a Lightning invoice
                        self.state.receive_flow = Some(ReceiveFlowState {
                            receive_type: ReceiveType::LightningInvoice,
                            address_or_invoice: String::new(),
                            amount_sats: Some(sats),
                            qr_data: String::new(),
                            is_generating: true,
                            error: None,
                        });
                        self.emit_state();

                        // Call the Boltz reverse swap handler
                        self.handle_reverse_swap(sats);
                        return; // handle_reverse_swap updates state and calls emit_state
                    }
                    _ => {
                        self.state.receive_flow = Some(ReceiveFlowState {
                            receive_type: ReceiveType::LightningInvoice,
                            address_or_invoice: String::new(),
                            amount_sats: None,
                            qr_data: String::new(),
                            is_generating: false,
                            error: Some(
                                "Enter an amount to generate a Lightning invoice".to_string(),
                            ),
                        });
                    }
                }
            }
        }

        self.state.busy.generating_address = false;
        self.emit_state();
    }

    /// Set the receive type before generating.
    pub(crate) fn handle_set_receive_type(&mut self, receive_type: ReceiveType) {
        let amount = self.state.receive_flow.as_ref().and_then(|f| f.amount_sats);
        self.state.receive_flow = Some(ReceiveFlowState {
            receive_type,
            address_or_invoice: String::new(),
            amount_sats: amount,
            qr_data: String::new(),
            is_generating: false,
            error: None,
        });
        self.emit_state();
    }

    /// Set receive amount.
    pub(crate) fn handle_set_receive_amount(&mut self, sats: u64) {
        if let Some(flow) = &mut self.state.receive_flow {
            flow.amount_sats = Some(sats);
        }
        self.emit_state();
    }
}
