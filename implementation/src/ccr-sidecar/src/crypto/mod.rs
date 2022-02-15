mod api;
pub mod providers;

use crate::messaging::http;
use crate::messaging::http::HttpClient;
use crate::messaging::serialization::deserialize_nullable_value;
use crate::options::Configuration;

use std::pin::Pin;
use std::sync::Arc;
use futures::future::Future;
use log::{debug, error};
use serde::{Serialize, Deserialize};

pub type AsyncSetKeyResult<'a> = Pin<Box<dyn Future<Output = Result<String, &'static str>> + Send + Sync + 'a>>;
pub type AsyncGetKeyResult<'a> = Pin<Box<dyn Future<Output = Result<Key, &'static str>> + Send + Sync + 'a>>;

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct KeyMaterial {
    #[serde(rename = "cryptoAlg")]
    pub crypto_alg: String,
    pub curve: String,
    pub params: String,
    #[serde(rename = "DHPublicKey")]
    pub dh_public_key: DHPublicKey,
    #[serde(rename = "Nonce")]
    pub nonce: String
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct DHPublicKey {
    pub expiry: String,
    #[serde(rename = "Parameters", deserialize_with = "deserialize_nullable_value")]
    pub parameters: String,
    #[serde(rename = "KeyValue")]
    pub key_value: String
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
#[serde(default)]
pub struct Key {
    /// The secret key value.
    pub value: String,
    /// The public key material.
    pub public_key_material: KeyMaterial
}

/// Interface of a key provider.
pub trait KeyProvider: Send + Sync {
    // TODO: change to async once there is async trait support that allows to return a 'Sync' future.
    /// Returns a future that that represents an asynchronous operation for setting the key.
    fn set_key(&self, key: Key) -> AsyncSetKeyResult;

    // TODO: change to async once there is async trait support that allows to return a 'Sync' future.
    /// Returns a future that contains the managed key once it completes.
    fn get_key(&self, id: String) -> AsyncGetKeyResult;
}

/// Invokes the crypto sidecar to generate a new key pair.
pub async fn gen_key_pair(http_client: &Arc<HttpClient>, config: &Configuration) -> Result<Key, &'static str> {
    debug!("Invoking the crypto sidecar to generate key pair");
    let endpoint = format!("http://{}:{}/", config.host, config.local.crypto_sidecar.port);
    let response = http_client.get(http::format_url(&endpoint, "/ecc/v1/generateKey"))
        .header(reqwest::header::CONTENT_TYPE, "application/json")
        .send().await.unwrap();
    if response.status() != 200 {
        let msg = "Failed to generate new key.";
        error!("{} Response: {:?}", msg, response);
        return Err(msg);
    }

    let response_json = response.json::<api::ForwardSecrecyKeyGenResponse>().await.unwrap();
    debug!("Response: {:?}", response_json);

    Ok(Key {
        value: response_json.private_key,
        public_key_material: KeyMaterial {
            crypto_alg: response_json.key_materials.crypto_alg,
            curve: response_json.key_materials.curve,
            params: response_json.key_materials.params,
            dh_public_key: DHPublicKey {
                expiry: response_json.key_materials.dh_public_key.expiry,
                parameters: response_json.key_materials.dh_public_key.parameters,
                key_value: response_json.key_materials.dh_public_key.key_value
            },
            nonce: "".to_string()
        }
    })
}

/// Invokes the crypto sidecar to decrypt the specified data.
pub async fn decrypt_data(data: String,
                          private_key: &str,
                          public_key: KeyMaterial,
                          nonce: &str,
                          http_client: &Arc<HttpClient>,
                          config: &Configuration) -> Result<String, &'static str> {
    let request_json = api::ForwardSecrecyDecryptionRequest {
        base64_data: data,
        base64_public_nonce: public_key.nonce,
        base64_nonce: nonce.to_string(),
        private_key: private_key.to_string(),
        public_key_material: api::ForwardSecrecyKeyMaterial {
            crypto_alg: public_key.crypto_alg,
            curve: public_key.curve,
            params: public_key.params,
            dh_public_key: api::ForwardSecrecyDHPublicKey {
                expiry: public_key.dh_public_key.expiry,
                parameters: public_key.dh_public_key.parameters,
                key_value: public_key.dh_public_key.key_value
            }
        }
    };

    debug!("Invoking the crypto sidecar to decrypt: {:?}", request_json);
    let endpoint = format!("http://{}:{}/", config.host, config.local.crypto_sidecar.port);
    let response = http_client.post(http::format_url(&endpoint, "/ecc/v1/decrypt"))
        .header(reqwest::header::CONTENT_TYPE, "application/json")
        .json(&request_json)
        .send().await.unwrap();
    if response.status() != 200 {
        let msg = "Failed to decrypt the request payload.";
        error!("{} Response: {:?}", msg, response);
        return Err(msg);
    }

    let response_json = response.json::<api::ForwardSecrecyCryptoResponse>().await.unwrap();
    debug!("Response: {:?}", response_json);
    Ok(response_json.base64_data)
}
