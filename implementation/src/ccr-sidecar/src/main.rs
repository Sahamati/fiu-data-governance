mod api;
mod controller;
mod crypto;
mod depa;
mod messaging;
mod logger;
mod options;
mod policy;
mod request;
mod service;

#[tokio::main]
async fn main() {
    // Parse the command line options and YAML configuration.
    let config = options::CommandLineOptions::parse();
    // Create and start the confidential request processing service.
    service::ConfidentialRequestProcessingService::run(config).await
}
