use crate::messaging::http;
use crate::messaging::http::HttpClient;
use super::super::{AsyncSetKeyResult, AsyncGetKeyResult, Key, KeyProvider};

use std::sync::Arc;
use std::sync::RwLock;
use std::time::{Duration, SystemTime};
use serde::{Serialize, Deserialize};
use log::{info, debug, error};

/// The AAD OAuth token required to authenticate to the Azure Key Vault.
#[derive(Clone, Default, Serialize, Deserialize, Debug)]
#[serde(default)]
struct ManagedIdentityToken {
    access_token: String,
    refresh_token: String,
    expires_in: String,
    expires_on: String,
    not_before: String,
    resource: String,
    token_type: String
}

/// An AKV set secret request.
#[derive(Clone, Default, Serialize, Deserialize, Debug)]
#[serde(default)]
struct SetSecretRequest {
    value: String,
    attributes: SecretAttributes
}

/// An AKV secret consisting of a value, id and its attributes.
#[derive(Clone, Default, Serialize, Deserialize, Debug)]
#[serde(default)]
struct SecretBundle {
    value: String,
    id: String,
    attributes: SecretAttributes
}

/// The AKV secret management attributes.
#[derive(Clone, Default, Serialize, Deserialize, Debug)]
#[serde(default)]
struct SecretAttributes {
    enabled: bool,
    exp: u64
}

/// Implementation of a key provider that uses Azure Key Vault for key management.
/// See https://docs.microsoft.com/en-us/azure/key-vault/.
#[derive(Debug)]
pub struct KeyVaultProvider {
    /// The URI of the key management service.
    uri: String,
    // The AAD OAuth token required to authenticate to the Azure Key Vault.
    token: RwLock<ManagedIdentityToken>,
    /// The HTTP client used to communicate with the key management service.
    http_client: Arc<HttpClient>,
}

impl KeyProvider for KeyVaultProvider {
    /// Returns a future that that represents an asynchronous operation for setting the key.
    fn set_key(&self, key: Key) -> AsyncSetKeyResult {
        Box::pin(
            async move {
                Ok(self.set_managed_key(key).await?)
            }
        )
    }

    /// Returns a future that contains the managed key once it completes.
    fn get_key(&self, id: String) -> AsyncGetKeyResult {
        Box::pin(
            async move {
                Ok(self.get_managed_key(id).await?)
            }
        )
    }
}

impl KeyVaultProvider {
    pub fn new(service_uri: String, http_client: Arc<HttpClient>) -> KeyVaultProvider {
        // Call the crypto service to get a new key pair.
        KeyVaultProvider {
            uri: service_uri,
            token: RwLock::new(ManagedIdentityToken::default()),
            http_client
        }
    }

    /// Sets the key information to the key management service.
    async fn set_managed_key(&self, key: Key) -> Result<String, &'static str> {
        let key_json = serde_json::to_string(&key).unwrap();
        let request_json = SetSecretRequest {
            value: key_json,
            attributes: SecretAttributes {
                enabled: true,
                exp: self.create_expiry_time(Duration::from_secs(31536000))
            }
        };

        // Access the Azure Key Vault using an oauth2 token to set the CCR key.
        // The key is stored as a secret as AKV does not support curve25519 EC keys.
        // See https://docs.microsoft.com/en-us/rest/api/keyvault/secrets/set-secret.
        let auth_token = self.get_or_create_authentication_token().await?;
        let endpoint = http::format_url(&self.uri, "/secrets/ccr-key?api-version=7.2");
        let response = self.http_client.put(endpoint)
            .header("Authorization", format!("Bearer {}", auth_token.access_token))
            .json(&request_json)
            .send().await.unwrap();
        // TODO: we should implement retry logic.
        if response.status() != 200 {
            let msg = "Failed to set key to the key management service.";
            error!("{} Response: {:?}", msg, response);
            return Err(msg);
        }

        let secret = response.json::<SecretBundle>().await.unwrap();
        debug!("AKV secret: {:?}", secret);
        let id = self.to_uuid(secret.id.split("/").last().unwrap());
        debug!("Identifier: {}", id);
        Ok(id.to_string())
    }

    /// Returns the key information from the key management service.
    async fn get_managed_key(&self, id: String) -> Result<Key, &'static str> {
        // TODO: implement local caching as optimization.
        // Access the Azure Key Vault using an oauth2 token to get the CCR key.
        // The key is stored as a secret as AKV does not support curve25519 EC keys.
        // See https://docs.microsoft.com/en-us/rest/api/keyvault/secrets/get-secret.
        let auth_token = self.get_or_create_authentication_token().await?;
        let path = format!("/secrets/ccr-key/{}?api-version=7.2", self.from_uuid(&id));
        let endpoint = http::format_url(&self.uri, &path);
        let response = self.http_client.get(endpoint)
            .header("Authorization", format!("Bearer {}", auth_token.access_token))
            .send().await.unwrap();
        // TODO: we should implement retry logic.
        if response.status() != 200 {
            let msg = "Failed to get key from the key management service.";
            error!("{} Response: {:?}", msg, response);
            return Err(msg);
        }

        let secret = response.json::<SecretBundle>().await.unwrap();
        debug!("AKV secret: {:?}", secret);
        let key: Key = serde_json::from_str(&secret.value).unwrap_or_default();
        debug!("Key: {:?}", key);
        Ok(key)
    }

    /// Returns the AKV authentication token from the local managed identities for Azure resources endpoint.
    async fn get_or_create_authentication_token(&self) -> Result<ManagedIdentityToken, &'static str> {
        let auth_token: ManagedIdentityToken;
        if self.is_authentication_token_unset_or_expired() {
            // If the authentication token is not set or expired, then get a new one.
            info!("Getting new authentication token as current one is expired or not set");
            let updated_token = self.get_authentication_token().await?;
            auth_token = updated_token.clone();
            let mut token = self.token.write().expect("Failed to get lock for updating the token.");
            *token = updated_token;
        } else {
            // Get the cached authentication token.
            auth_token = self.token.read().expect("Failed to get read lock for the token.").clone();
        }

        Ok(auth_token)
    }

    /// Returns the AKV authentication token from the local managed identities for Azure resources endpoint.
    async fn get_authentication_token(&self) -> Result<ManagedIdentityToken, &'static str> {
        // Contact the local managed identities for Azure resources endpoint to get the
        // AAD OAuth token required to authenticate to the Azure Key Vault.
        // See https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/tutorial-linux-vm-access-nonaad#access-data.
        let api_version = "2018-02-01";
        let resource = "https%3A%2F%2Fvault.azure.net";
        let path = format!("/metadata/identity/oauth2/token?api-version={}&resource={}", api_version, resource);
        let endpoint = http::format_url("http://169.254.169.254", &path);
        let response = self.http_client.get(endpoint)
            .header("Metadata", "true")
            .send().await.unwrap();
        // TODO: we should implement retry logic.
        if response.status() != 200 {
            let msg = "Failed to get AAD OAuth token for accessing the Azure Key Vault.";
            error!("{} Response: {:?}", msg, response);
            return Err(msg);
        }

        let auth_token = response.json::<ManagedIdentityToken>().await.unwrap();
        debug!("AKV authentication token: {:?}", auth_token);
        Ok(auth_token)
    }

    /// Returns true if the AKV authentication token is not set or has expired.
    fn is_authentication_token_unset_or_expired(&self) -> bool {
        let token = self.token.read().expect("Failed to get lock for reading the token.");
        if token.access_token.is_empty() {
            // The token has not been set yet.
            return true;
        }

        // Get the current and token epoch since the UNIX epoch.
        let token_epoch = token.expires_on.parse::<u64>().unwrap_or_default();
        let current_epoch = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH)
            .unwrap_or(Duration::from_secs(token_epoch)).as_secs();
        if current_epoch >= token_epoch {
            // The token has expired.
            return true;
        }

        return false;
    }

    /// Returns an expiry time using the specified offset from the current time.
    fn create_expiry_time(&self, offset: Duration) -> u64 {
        let current_epoch = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH);
        current_epoch.unwrap_or(Duration::from_secs(0)).as_secs() + offset.as_secs()
    }

    /// Convert a UUID returned from the AKV to the expected representation that includes hyphens.
    fn to_uuid(&self, id: &str) -> String {
        let mut uuid = String::new();
        uuid.push_str(&id[0..8]);
        uuid.push_str("-");
        uuid.push_str(&id[8..12]);
        uuid.push_str("-");
        uuid.push_str(&id[12..16]);
        uuid.push_str("-");
        uuid.push_str(&id[16..20]);
        uuid.push_str("-");
        uuid.push_str(&id[20..32]);
        uuid
    }

    /// Convert a UUID to the non-hyphenated representation expected by AKV.
    fn from_uuid(&self, id: &str) -> String {
        let mut uuid = String::new();
        uuid.push_str(&id[0..8]);
        uuid.push_str(&id[9..13]);
        uuid.push_str(&id[14..18]);
        uuid.push_str(&id[19..23]);
        uuid.push_str(&id[24..36]);
        uuid
    }
}
