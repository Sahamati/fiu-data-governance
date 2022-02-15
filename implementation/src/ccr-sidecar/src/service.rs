use super::controller::{Controller, ProxyRequest, ProxyResponse};
use super::crypto::KeyProvider;
use super::crypto::providers::azure::KeyVaultProvider;
use super::messaging::http::HttpClient;
use super::messaging::proto::envoy::service::ext_proc::v3::external_processor_server::{ExternalProcessor, ExternalProcessorServer};
use super::options::Configuration;

use std::net::SocketAddr;
use std::pin::Pin;
use std::sync::Arc;
use futures::{Stream, StreamExt};
use tonic::{Request, Response, Status};
use tonic::transport::Server;
use log::{info, error};

type ProxyStreamingRequest = Request<tonic::Streaming<ProxyRequest>>;

/// Implements a CCR service that processes confidential requests from the CCR proxy.
/// The service implements an external processor that the External Processing filter
/// of the Envoy proxy can communicate with using gRPC. Read more details:
/// https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/ext_proc_filter
#[derive(Debug)]
pub struct ConfidentialRequestProcessingService;

impl ConfidentialRequestProcessingService {
    /// Creates and runs a new confidential request processing service that is
    /// configured with the specified options.
    pub async fn run(config: Configuration) {
        // The service will bind to this address.
        let address: SocketAddr = format!("0.0.0.0:{}", config.port)
            .parse().expect("Unable to parse socket address");

        // Initialize an HTTP client that can be used by the service.
        let http_client = HttpClient::builder()
            .use_rustls_tls()
            .build().unwrap();
        let http_client = Arc::new(http_client);

        // Initialize a key provider that can be used by the service.
        let key_provider: KeyVaultProvider;
        if config.services.key_management.provider == "azure-key-vault" {
            // Only Azure Key Vault is currently supported.
            key_provider = KeyVaultProvider::new(
                config.services.key_management.uri.clone(),
                http_client.clone());
        } else {
            error!("Unsupported key management provider: {}", config.services.key_management.provider);
            std::process::exit(1);
        }

        // Create a new instance of the proxy request processor.
        let server = ExternalProcessorServer::new(ConfidentialRequestProcessor {
            // Initialize the context containing the shared service state.
            config: config.clone(),
            key_provider: Arc::new(Box::new(key_provider)),
            http_client: http_client.clone()
        });

        // Start the service.
        let server = Server::builder().add_service(server).serve(address);
        info!("Listening on http://{}", address);
        if let Err(e) = server.await {
            error!("server error: {}", e);
        }
    }
}

struct ConfidentialRequestProcessor {
    config: Configuration,
    key_provider: Arc<Box<dyn KeyProvider>>,
    http_client: Arc<HttpClient>
}

#[tonic::async_trait]
impl ExternalProcessor for ConfidentialRequestProcessor {
    type ProcessStream = Pin<Box<dyn Stream<Item = Result<ProxyResponse, Status>> + Send + Sync + 'static>>;

    async fn process(&self, request: ProxyStreamingRequest) -> Result<Response<Self::ProcessStream>, Status> {
        if let Some(remote_addr) = request.remote_addr() {
            info!("Received confidential request from '{:?}'", remote_addr);
        } else {
            info!("Received confidential request from 'unavailable'");
        }

        // Create a new controller for processing this proxy request stream.
        let mut controller = Controller::new(self.config.clone(), self.key_provider.clone(), self.http_client.clone());

        // Process the gRPC request asynchronously by connecting to its bi-directional stream.
        let mut stream = request.into_inner();
        let output = async_stream::try_stream! {
            while let Some(msg) = stream.next().await {
                // Handle the next proxy request from the stream.
                yield controller.handle_proxy_request(msg.unwrap()).await;
            }
        };

        Ok(Response::new(Box::pin(output) as Self::ProcessStream))
    }
}
