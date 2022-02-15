use crate::messaging::serialization::deserialize_nullable_value;

use serde::{Serialize, Deserialize};

pub const AA_ENTITY_INFO_REQUEST: &str = "entityInfo/AA";

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct EntityInfoResponse {
    pub entities: Vec<EntityInfoEntry>
}

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct EntityInfoEntry {
    pub ver: String,
    pub timestamp: String,
    #[serde(rename = "txnid")]
    pub txn_id: String,
    pub requester: Requester,
    #[serde(rename = "entityinfo")]
    pub entity_info: EntityInfo
}

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct Requester {
    pub name: String,
    pub id: String
}

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct EntityInfo {
    pub name: String,
    pub id: String,
    pub code: String,
    #[serde(rename = "entityhandle")]
    pub entity_handle: String,
    #[serde(rename = "Identifiers")]
    pub identifiers: Vec<Identifier>,
    #[serde(rename = "baseurl")]
    pub base_url: String,
    #[serde(rename = "webviewurl", deserialize_with = "deserialize_nullable_value")]
    pub web_view_url: String,
    #[serde(rename = "fitypes", deserialize_with = "deserialize_nullable_value")]
    pub fit_ypes: Vec<String>,
    pub certificate: Certificate,
    #[serde(rename = "tokeninfo")]
    pub token_info: TokenInfo,
    #[serde(deserialize_with = "deserialize_nullable_value")]
    pub gsp: String,
    pub signature: Signature,
    #[serde(rename = "inboundports", deserialize_with = "deserialize_nullable_value")]
    pub inbound_ports: Vec<String>,
    #[serde(rename = "outboundports", deserialize_with = "deserialize_nullable_value")]
    pub outbound_ports: Vec<String>,
    #[serde(rename = "ips", deserialize_with = "deserialize_nullable_value")]
    pub ips: Vec<String>,
    #[serde(rename = "credentialsPk", deserialize_with = "deserialize_nullable_value")]
    pub credentials_pk: String
}

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct Identifier {
    pub category: String,
    #[serde(rename = "type")]
    pub id_type: String
}

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct Certificate {
    pub alg: String,
    pub e: String,
    pub kid: String,
    pub kty: String,
    pub n: String,
    #[serde(rename = "use")]
    pub cert_use: String
}

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct TokenInfo {
    #[serde(deserialize_with = "deserialize_nullable_value")]
    pub url: String,
    #[serde(rename = "maxcalls", deserialize_with = "deserialize_nullable_value")]
    pub max_calls: i32,
    pub desc: String
}

#[derive(Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct Signature {
    #[serde(rename = "signValue")]
    pub sign_value: String
}
