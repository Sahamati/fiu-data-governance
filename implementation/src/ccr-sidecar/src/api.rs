use super::crypto::KeyMaterial;
use super::depa::consent::ConsentArtefact;

use serde::{Serialize, Deserialize};

pub const CCR_KEY_REQUEST: &str = "/api/ccr/key";
pub const CCR_PROCESS_REQUEST: &str = "/api/ccr/process";

// Response to the GET CCR key request.
#[derive(Default, Serialize, Deserialize, Debug)]
pub struct KeyResponse {
    pub ver: String,
    pub timestamp: String,
    #[serde(rename = "txnid")]
    pub txn_id: String,
    #[serde(rename = "KeyMaterial")]
    pub key_material: KeyMaterial
}

// Response to process data confidentially.
#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct ProcessRequest {
    pub ver: String,
    pub timestamp: String,
    #[serde(rename = "txnid")]
    pub txn_id: String,
    pub payload: Vec<ProcessPayloadItem>,
    #[serde(rename = "Consent")]
    pub consent: Consent
}

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct ProcessPayloadItem {
    pub id: String,
    pub data: Vec<ProcessDataItem>,
    #[serde(rename = "KeyMaterial", skip_serializing)]
    pub key_material: KeyMaterial
}

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct ProcessDataItem {
    #[serde(rename = "encryptedData")]
    pub encrypted_data: String,
    pub metadata: String
}

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct Consent {
    pub signature: String,
    #[serde(rename = "consentArtefact")]
    pub consent_artefact: ConsentArtefact
}
