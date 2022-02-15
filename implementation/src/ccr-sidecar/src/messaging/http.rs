pub type HttpClient = reqwest::Client;

pub type Headers = super::proto::envoy::config::core::v3::HeaderMap;
pub type HeadersMutation = super::proto::envoy::service::ext_proc::v3::HeaderMutation;
pub type HeaderMutation = super::proto::envoy::config::core::v3::HeaderValueOption;
pub type BodyMutation = super::proto::envoy::service::ext_proc::v3::BodyMutation;

type HeaderValueMutationAction = super::proto::envoy::config::core::v3::header_value_option::HeaderAppendAction;

pub const METHOD_HEADER: &str = ":method";
pub const PATH_HEADER: &str = ":path";
pub const AUTHORITY_HEADER: &str = ":authority";
pub const CCR_IS_INCOMING_HEADER: &str = "x-ccr-is-incoming";

pub enum StatusCode {
    Ok = 200,
    BadRequest = 400,
    Forbidden = 403,
    InternalError = 500,
    ServiceUnavailable = 503
}

/// Creates a mutation that adds and/or removes the specified headers.
pub fn mutate_headers(set_headers: Vec<HeaderMutation>, remove_headers: Vec<String>) -> HeadersMutation {
    HeadersMutation {
        set_headers,
        remove_headers
    }
}

/// Creates a single header mutation.
pub fn mutate_header(key: &str, value: &str, append: bool) -> HeaderMutation {
    HeaderMutation {
        header: Some(super::proto::envoy::config::core::v3::HeaderValue {
            key: key.to_string(),
            value: value.to_string()
        }),
        append: Some(append),
        // NOTE: Envoy does not implement this yet.
        append_action: HeaderValueMutationAction::OverwriteIfExistsOrAdd as i32
    }
}

/// Creates a mutation that replaces the existing body with the specified data.
pub fn mutate_body(data: Vec<u8>) -> BodyMutation {
    BodyMutation {
        mutation: Some(super::proto::envoy::service::ext_proc::v3::body_mutation::Mutation::Body(data))
    }
}

pub fn format_url(endpoint: &str, path: &str) -> String {
    let mut endpoint: String = endpoint.to_string();
    let mut path: String = path.to_string();

    if endpoint.ends_with("/") {
        endpoint.pop();
    }

    if path.starts_with("/") {
        path.remove(0);
    }

    format!("{}/{}", endpoint, path)
}
