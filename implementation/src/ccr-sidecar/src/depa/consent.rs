use crate::messaging::serialization::deserialize_nullable_value;

use serde::{Serialize, Deserialize};

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct ConsentArtefact {
    pub ver: String,
    #[serde(rename = "txnid")]
    pub txn_id: String,
    #[serde(rename = "consentId")]
    pub consent_id: String,
    pub status: String,
    #[serde(rename = "createTimestamp")]
    pub create_timestamp: String,
    #[serde(rename = "signedConsent")]
    pub signed_consent: String,
    #[serde(rename = "ConsentUse", deserialize_with = "deserialize_nullable_value")]
    pub consent_use: ConsentUse
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct ConsentUse {
    #[serde(rename = "logUri")]
    pub log_uri: String,
    pub count: i32,
    #[serde(rename = "lastUseDateTime")]
    pub last_use_date_time: String
}
