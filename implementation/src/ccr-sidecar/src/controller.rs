use super::api;
use super::crypto::{KeyMaterial, KeyProvider, gen_key_pair, decrypt_data};
use super::depa::aa::{EntityInfoResponse, EntityInfoEntry, AA_ENTITY_INFO_REQUEST};
use super::messaging::http;
use super::messaging::http::HttpClient;
use super::messaging::http::StatusCode;
use super::options::Configuration;
use super::policy::{PolicyCheckRequest, PolicyCheckResponse, PolicyRule};
use super::request::RequestInfo;

use std::sync::Arc;
use log::{info, debug};
use serde_json;
use uuid::Uuid;

pub type ProxyRequest = super::messaging::proto::envoy::service::ext_proc::v3::ProcessingRequest;
pub type ProxyResponse = super::messaging::proto::envoy::service::ext_proc::v3::ProcessingResponse;

type ConfidentialRequest = super::messaging::proto::envoy::service::ext_proc::v3::processing_request::Request;
type ConfidentialResponse = super::messaging::proto::envoy::service::ext_proc::v3::processing_response::Response;
type ImmediateResponse = super::messaging::proto::envoy::service::ext_proc::v3::ImmediateResponse;
type HeadersResponse = super::messaging::proto::envoy::service::ext_proc::v3::HeadersResponse;
type BodyResponse = super::messaging::proto::envoy::service::ext_proc::v3::BodyResponse;
type MutationResponse = super::messaging::proto::envoy::service::ext_proc::v3::CommonResponse;
type MutationResponseStatus = super::messaging::proto::envoy::service::ext_proc::v3::common_response::ResponseStatus;

pub struct Controller {
    config: Configuration,
    key_provider: Arc<Box<dyn KeyProvider>>,
    http_client: Arc<HttpClient>,
    current_request: Option<RequestInfo>
}

impl Controller {
    pub fn new(config: Configuration, key_provider: Arc<Box<dyn KeyProvider>>, http_client: Arc<HttpClient>) -> Self {
        Controller {
            config,
            key_provider,
            http_client,
            current_request: None
        }
    }

    /// Handles the specified proxy request.
    pub async fn handle_proxy_request(&mut self, request: ProxyRequest) -> ProxyResponse {
        if let Some(ConfidentialRequest::RequestHeaders(headers_msg)) = &request.request {
            debug!("Handling proxy request: {:?}", request);
            if let Some(headers) = &headers_msg.headers {
                return self.process_confidential_request_headers(headers).await;
            }
        } else if let Some(ConfidentialRequest::RequestBody(body_msg)) = &request.request {
            return self.process_confidential_request_body(body_msg.body.clone()).await;
        } else if let Some(ConfidentialRequest::ResponseHeaders(headers_msg)) = &request.request {
            debug!("Handling proxy response: {:?}", request);
            if let Some(headers) = &headers_msg.headers {
                return self.process_confidential_response_headers(headers).await;
            }
        } else if let Some(ConfidentialRequest::ResponseBody(body_msg)) = &request.request {
            return self.process_confidential_response_body(body_msg.body.clone()).await;
        }

        self.create_error_proxy_response(StatusCode::BadRequest, "unable to process request")
    }

    /// Processes the specified confidential request headers.
    async fn process_confidential_request_headers(&mut self, headers: &http::Headers) -> ProxyResponse {
        let request_info = RequestInfo::new(headers.clone());
        if request_info.method == "GET" && request_info.path == api::CCR_KEY_REQUEST {
            // This is a GET CCR key request.
            return self.handle_get_key_request().await;
        }

        // This is a confidential request. Cache the request info and return the headers.
        self.current_request = Some(request_info);
        return self.create_request_headers_proxy_response(MutationResponseStatus::Continue, None, None);
    }

    /// Processes the specified confidential request body.
    async fn process_confidential_request_body(&self, body: Vec<u8>) -> ProxyResponse {
        if self.current_request.is_none() {
            // This should normally never happen because the proxy guarantees
            // to first send the request headers before the request body.
            return self.create_error_proxy_response(StatusCode::InternalError, "unable to process request body");
        }

        let current_request = self.current_request.as_ref().unwrap();
        let method = &current_request.method;
        let path = &current_request.path;

        // TODO: deny requests that do not use the CCR API or do not originate from another attested CCR service.
        // This logic currently allows such requests to go through.
        info!("Handling confidential {} '{}' request", method, path);
        if method == "POST" && path == api::CCR_PROCESS_REQUEST {
            // Decrypt the request payload.
            let processed_body_result = self.decrypt_request_payload(body.clone()).await;
            if let Err(error_proxy_response) = processed_body_result {
                return error_proxy_response;
            }

            // Get the AA entity info from the certificate registry that will be used to
            // validate the signed consent in the policy engine.
            let entity_info = self.get_aa_entity_info().await.unwrap();

            // Check and enforce the specified request policy rule.
            let mutated_body = processed_body_result.unwrap();
            let policy_input = self.create_process_request_policy_input(entity_info, &mutated_body);
            if !self.check_policy(policy_input, current_request.get_request_policy_rule()).await {
                // The policy check failed, so forbid the request.
                return self.create_error_proxy_response(StatusCode::Forbidden, "request is forbidden");
            }

            if self.is_body_mutated(&body, &mutated_body) {
                // The request body has been mutated, so return a body mutation response.
                let content_length_header_mutation = http::mutate_header(reqwest::header::CONTENT_LENGTH.as_str(),
                    &mutated_body.len().to_string(), false);
                let headers_mutation = http::mutate_headers(Vec::from([content_length_header_mutation]), Vec::new());
                let body_mutation = http::mutate_body(mutated_body);
                return self.create_request_body_proxy_response(MutationResponseStatus::Continue,
                    Some(headers_mutation), Some(body_mutation));
            }
        }

        // Nothing to do, so return the request body as is.
        self.create_request_body_proxy_response(MutationResponseStatus::Continue, None, None)
    }

    /// Processes the specified confidential response headers.
    async fn process_confidential_response_headers(&mut self, _: &http::Headers) -> ProxyResponse {
        return self.create_response_headers_proxy_response(MutationResponseStatus::Continue, None, None);
    }

    /// Processes the specified confidential response body.
    async fn process_confidential_response_body(&self, body: Vec<u8>) -> ProxyResponse {
        let current_request = self.current_request.as_ref().unwrap();
        let method = &current_request.method;
        let path = &current_request.path;
        info!("Handling confidential {} '{}' response", method, path);
        if method == "POST" && path == api::CCR_PROCESS_REQUEST {
            // Check and enforce the specified response policy rule.
            let policy_input: serde_json::Value = serde_json::from_slice(&body).unwrap();
            if !self.check_policy(policy_input, current_request.get_response_policy_rule()).await {
                // The policy check failed, so forbid the response.
                return self.create_error_proxy_response(StatusCode::Forbidden, "response is forbidden");
            }
        }

        // Nothing to do, so return the response body as is.
        self.create_response_body_proxy_response(MutationResponseStatus::Continue, None, None)
    }

    /// Handles the GET CCR key request.
    async fn handle_get_key_request(&self) -> ProxyResponse {
        info!("Handling GET '{}' request", api::CCR_KEY_REQUEST);

        // Generate a private/public key pair unique to this request.
        if let Ok(key) = gen_key_pair(&self.http_client, &self.config).await {
            // Store the key in the provider for future retrieval and get a transaction id
            // that can be used to identify the transaction and for future key retrieval.
            let txn_id = self.key_provider.set_key(key.clone()).await.unwrap_or_default();
            if txn_id.is_empty() {
                // Unable to set the key to the key provider, so return an error.
                return self.create_error_proxy_response(StatusCode::ServiceUnavailable,
                    "unable to return a CCR key, please retry");
            }

            // Prepare the CCR key payload for the client.
            let public_key = key.public_key_material;
            let key_response = api::KeyResponse {
                ver: "0.0.1".to_string(),
                timestamp: self.get_current_timestamp(),
                txn_id,
                key_material: KeyMaterial {
                    crypto_alg: public_key.crypto_alg,
                    curve: "Curve25519".to_string(),
                    params: "cipher=AES/GCM/NoPadding;KeyPairGenerator=ECDH".to_string(),
                    dh_public_key: public_key.dh_public_key,
                    nonce: self.gen_nonce()
                }
            };

            let response_json = serde_json::to_string(&key_response).unwrap();
            info!("Responding with CCR key: {}", response_json);
            self.create_immediate_proxy_response(StatusCode::Ok, response_json, "CCR key response")

        } else {
            // Unable to generate a new key, so return an error.
            return self.create_error_proxy_response(StatusCode::ServiceUnavailable,
                "unable to return a CCR key, please retry");
        }
    }

    /// Creates the policy input for the specified CCR process request by combining
    /// the AA entity info and the request payload.
    fn create_process_request_policy_input(&self,
                                           entity_info: EntityInfoResponse,
                                           payload: &Vec<u8>) -> serde_json::Value {
        // Combine the two JSON values into one input for the policy engine.
        let mut policy_input_json: serde_json::Value = serde_json::from_slice(payload).unwrap();
        let entity_info_json: serde_json::Value = serde_json::to_value(entity_info).unwrap();
        if policy_input_json.is_object() && entity_info_json.is_object() {
            let policy_input_map = policy_input_json.as_object_mut().unwrap();
            let entity_info_map = entity_info_json.as_object().unwrap();
            for (key, value) in entity_info_map {
                policy_input_map.insert(key.to_string(), value.clone());
            }
        }

        return policy_input_json;
    }

    /// Invokes the policy engine to check if the input satisfies the installed policy.
    async fn check_policy(&self, input: serde_json::Value, rule: PolicyRule) -> bool {
        let request_json = PolicyCheckRequest {
            input
        };

        info!("Checking policy for: {:?}", request_json);
        let endpoint = format!("http://{}:{}/", self.config.host, self.config.local.policy_engine.port);
        let path = format!("/v1/data/ccr/policy/{}?explain=notes&pretty", rule);
        let response = self.http_client.post(http::format_url(&endpoint, &path))
            .json(&request_json)
            .send().await.unwrap();
        let response_json = response.json::<PolicyCheckResponse>().await.unwrap();
        info!("Policy check result: {}", response_json.result);
        return response_json.result;
    }

    /// Decrypts the payload of the specified request and returns a new body if required.
    async fn decrypt_request_payload(&self, body: Vec<u8>) -> Result<Vec<u8>, ProxyResponse> {
        let request_json: serde_json::Result<api::ProcessRequest> = serde_json::from_slice(&body);
        match request_json {
            Ok(request_json) => {
                // Decrypt the payload in the request body.
                info!("Decrypting the request payload");
                let mut request_json = request_json;

                let key = self.key_provider.get_key(request_json.txn_id.clone()).await.unwrap_or_default();
                if key.value.is_empty() {
                    // Unable to get the CCR key from the key provider, so return an error.
                    return Err(self.create_error_proxy_response(StatusCode::ServiceUnavailable,
                        "unable to retrieve the CCR key associated with this transaction id, please retry"));
                }

                // Iterate over the payload array in the request and decrypt each data item.
                let encrypted_payload = &mut request_json.payload;
                for i in 0..encrypted_payload.len() {
                    let encrypted_data_json = &mut encrypted_payload[i];
                    let encrypted_payload = &mut encrypted_data_json.data;
                    for j in 0..encrypted_payload.len() {
                        let encrypted_data = &encrypted_payload[j].encrypted_data;
                        let decrypted_data = decrypt_data(encrypted_data.to_string(),
                            &key.value, encrypted_data_json.key_material.clone(), &self.gen_nonce(),
                            &self.http_client, &self.config).await;
                        match decrypted_data {
                            Ok(decrypted_data) => {
                                encrypted_payload[j].encrypted_data = decrypted_data;
                            },
                            Err(_) => {
                                // Unable to decrypt the data, so return an error.
                                return Err(self.create_error_proxy_response(StatusCode::BadRequest,
                                    "unable to decrypt the request payload"));
                            }
                        }
                    }
                }

                return Ok(serde_json::to_vec(&request_json).unwrap());
            },
            Err(_) => {
                // Unable to parse the JSON request, so return an error.
                return Err(self.create_error_proxy_response(StatusCode::BadRequest, "unable to parse the request body"));
            }
        }
    }

    /// Returns the AA entity info from the certificate registry.
    async fn get_aa_entity_info(&self) -> Result<EntityInfoResponse, ProxyResponse> {
        let endpoint = self.config.services.aa_cert_registry.uri.clone();
        info!("Asking for AA entity info from {}", &endpoint);
        let response = self.http_client.get(http::format_url(&endpoint, AA_ENTITY_INFO_REQUEST))
            .send().await.unwrap();
        if response.status() != 200 {
            // Unable to get the AA entity info, so return an error.
            return Err(self.create_error_proxy_response(StatusCode::ServiceUnavailable,
                "unable to retrieve the get key the AA entity info, please retry"));
        }

        let entity_info_entries = response.json::<Vec<EntityInfoEntry>>().await.unwrap();
        let entity_info = EntityInfoResponse { entities: entity_info_entries };
        info!("Received the AA entity info: {:?}", entity_info);
        return Ok(entity_info);
    }

    /// Checks if the body has been mutated.
    fn is_body_mutated(&self, original: &Vec<u8>, mutated: &Vec<u8>) -> bool {
        // Optimization: if the lengths are different, then the body is mutated.
        if original.len() != mutated.len() {
            return true;
        }

        let matching = original.iter().zip(mutated.iter()).filter(|&(a, b)| a == b).count();
        matching == original.len() && matching == mutated.len()
    }

    /// Gets the current timestamp as a string.
    fn get_current_timestamp(&self) -> String {
        chrono::offset::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true)
    }

    /// Generates a b64 encoded nonce.
    fn gen_nonce(&self) -> String {
        // For now we do not use a nonce.
        let nonce = Uuid::nil().to_string();
        base64::encode(nonce.as_bytes())
    }

    /// Creates a request headers proxy response containing the specified mutated headers as payload.
    fn create_request_headers_proxy_response(&self,
                                              status: MutationResponseStatus,
                                              headers_mutation: Option<http::HeadersMutation>,
                                              body_mutation: Option<http::BodyMutation>) -> ProxyResponse {
        let response = ConfidentialResponse::RequestHeaders(HeadersResponse {
            response: Some(self.create_mutation_response(status, headers_mutation, body_mutation))
        });

        ProxyResponse {
            dynamic_metadata: None,
            mode_override: None,
            response: Some(response)
        }
    }

    /// Creates a response headers proxy response containing the specified mutated headers as payload.
    fn create_response_headers_proxy_response(&self,
                                               status: MutationResponseStatus,
                                               headers_mutation: Option<http::HeadersMutation>,
                                               body_mutation: Option<http::BodyMutation>) -> ProxyResponse {
        let response = ConfidentialResponse::ResponseHeaders(HeadersResponse {
            response: Some(self.create_mutation_response(status, headers_mutation, body_mutation))
        });

        ProxyResponse {
            dynamic_metadata: None,
            mode_override: None,
            response: Some(response)
        }
    }

    /// Creates a request body proxy response containing the specified mutated body as payload.
    fn create_request_body_proxy_response(&self,
                                           status: MutationResponseStatus,
                                           headers_mutation: Option<http::HeadersMutation>,
                                           body_mutation: Option<http::BodyMutation>) -> ProxyResponse {
        let response = ConfidentialResponse::RequestBody(BodyResponse {
            response: Some(self.create_mutation_response(status, headers_mutation, body_mutation))
        });

        ProxyResponse {
            dynamic_metadata: None,
            mode_override: None,
            response: Some(response)
        }
    }

    /// Creates a response body proxy response containing the specified mutated body as payload.
    fn create_response_body_proxy_response(&self,
                                            status: MutationResponseStatus,
                                            headers_mutation: Option<http::HeadersMutation>,
                                            body_mutation: Option<http::BodyMutation>) -> ProxyResponse {
        let response = ConfidentialResponse::ResponseBody(BodyResponse {
            response: Some(self.create_mutation_response(status, headers_mutation, body_mutation))
        });

        ProxyResponse {
            dynamic_metadata: None,
            mode_override: None,
            response: Some(response)
        }
    }

    /// Creates an immediate proxy response with the specified status and payload. Immediate
    /// responses are used by the CCR proxy to send a response to the client, without having
    /// to go through the business logic container.
    fn create_immediate_proxy_response(&self, status: StatusCode, body: String, details: &str) -> ProxyResponse {
        let response = ConfidentialResponse::ImmediateResponse(ImmediateResponse {
            status: Some(super::messaging::proto::envoy::r#type::v3::HttpStatus {
                code: status as i32
            }),
            headers: None,
            body: body,
            grpc_status: None,
            details: details.to_string()
        });

        ProxyResponse {
            dynamic_metadata: None,
            mode_override: None,
            response: Some(response)
        }
    }

    /// Creates an immediate error proxy response.
    fn create_error_proxy_response(&self, status: StatusCode, error: &str) -> ProxyResponse {
        self.create_immediate_proxy_response(status, "".to_string(), error)
    }

    /// Creates a response that notifies the proxy how to mutate a request or response.
    fn create_mutation_response(&self,
                                status: MutationResponseStatus,
                                headers_mutation: Option<http::HeadersMutation>,
                                body_mutation: Option<http::BodyMutation>) -> MutationResponse {
        MutationResponse {
            status: status as i32,
            header_mutation: headers_mutation,
            body_mutation,
            trailers: None,
            clear_route_cache: false
        }
    }
}
