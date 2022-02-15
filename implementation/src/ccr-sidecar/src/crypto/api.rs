use serde::{Serialize, Deserialize};

// The API of the crypto sidecar implemented by https://github.com/Sahamati/rahasya.

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct ForwardSecrecyKeyGenResponse {
    #[serde(rename = "privateKey")]
    pub private_key: String,
    #[serde(rename = "KeyMaterials")]
    pub key_materials: ForwardSecrecyKeyMaterial,
    #[serde(rename = "errorInfo")]
    pub error_info: Option<ErrorInfo>
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct ForwardSecrecyKeyMaterial {
    #[serde(rename = "cryptoAlg")]
    pub crypto_alg: String,
    pub curve: String,
    pub params: String,
    #[serde(rename = "DHPublicKey")]
    pub dh_public_key: ForwardSecrecyDHPublicKey
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct ForwardSecrecyDHPublicKey {
    pub expiry: String,
    #[serde(rename = "Parameter")]
    pub parameters: String,
    #[serde(rename = "KeyValue")]
    pub key_value: String
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct ForwardSecrecyDecryptionRequest {
    #[serde(rename = "base64Data")]
    pub base64_data: String,
    #[serde(rename = "base64RemoteNonce")]
    pub base64_public_nonce: String,
    #[serde(rename = "base64YourNonce")]
    pub base64_nonce: String,
    #[serde(rename = "ourPrivateKey")]
    pub private_key: String,
    #[serde(rename = "remoteKeyMaterial")]
    pub public_key_material: ForwardSecrecyKeyMaterial
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct ForwardSecrecyCryptoResponse {
    #[serde(rename = "base64Data")]
    pub base64_data: String,
    #[serde(rename = "errorInfo")]
    pub error_info: Option<ErrorInfo>
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct ErrorInfo {
    #[serde(rename = "errorCode")]
    pub error_code: String,
    #[serde(rename = "errorMessage")]
    pub error_message: String
}
