use std::fmt;
use serde::{Serialize, Deserialize};

#[derive(Default, Serialize, Deserialize, Debug)]
pub struct PolicyCheckRequest {
    pub input: serde_json::Value
}

#[derive(Default, Serialize, Deserialize, Debug)]
pub struct PolicyCheckResponse {
    pub result: bool
}

#[derive(Clone, Copy, Debug)]
pub enum PolicyRule {
    AllowIncomingRequest,
    AllowIncomingResponse,
    AllowOutgoingRequest,
    AllowOutgoingResponse
}

impl fmt::Display for PolicyRule {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            PolicyRule::AllowIncomingRequest => write!(f, "allow_incoming_request"),
            PolicyRule::AllowIncomingResponse => write!(f, "allow_incoming_response"),
            PolicyRule::AllowOutgoingRequest => write!(f, "allow_outgoing_request"),
            PolicyRule::AllowOutgoingResponse => write!(f, "allow_outgoing_response")
        }
    }
}
