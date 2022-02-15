use super::messaging::http;
use super::policy::PolicyRule;

#[derive(Clone, Debug)]
pub struct RequestInfo {
    pub method: String,
    pub path: String,
    pub host: String,
    is_incoming: bool
}

impl RequestInfo {
    pub fn new(headers: http::Headers) -> Self {
        let method = Self::extract_header(http::METHOD_HEADER, &headers);
        let path = Self::extract_header(http::PATH_HEADER, &headers);
        let mut host = Self::extract_header(http::AUTHORITY_HEADER, &headers);
        if host.is_empty() {
            host = Self::extract_header(reqwest::header::HOST.as_str(), &headers);
        }

        let is_incoming = Self::extract_header(http::CCR_IS_INCOMING_HEADER, &headers)
            .parse::<bool>().unwrap_or(false);

        RequestInfo {
            method,
            path,
            host,
            is_incoming
        }
    }

    pub fn get_request_policy_rule(&self) -> PolicyRule {
        if self.is_incoming {
            PolicyRule::AllowIncomingRequest
        } else {
            PolicyRule::AllowOutgoingRequest
        }
    }

    pub fn get_response_policy_rule(&self) -> PolicyRule {
        if self.is_incoming {
            PolicyRule::AllowOutgoingResponse
        } else {
            PolicyRule::AllowIncomingResponse
        }
    }

    fn extract_header(key: &str, headers: &http::Headers) -> String {
        let header = headers.headers.iter().find(|header| header.key == key);
        if let Some(header) = header {
            return header.value.to_string();
        }

        "".to_string()
    }
}
