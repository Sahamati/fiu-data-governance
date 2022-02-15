use super::logger;

use serde::{Deserialize, Serialize};
use serde_yaml;
use structopt::StructOpt;
use log::error;

#[derive(Clone, StructOpt, Debug)]
#[structopt(name = "ccr-sidecar")]
pub struct CommandLineOptions {
    /// The YAML configuration file for the sidecar.
    #[structopt(short, long, default_value = "")]
    pub configuration: String,
    /// Enables verbose output.
    #[structopt(short, long)]
    pub verbose: bool
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct YamlConfiguration {
    /// The configuration of this sidecar.
    pub sidecar: Configuration
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct Configuration {
    /// The host of this sidecar.
    pub host: String,
    /// The listening port of this sidecar.
    pub port: String,
    /// The trusted local CCR containers.
    pub local: LocalConfiguration,
    /// The trusted external services.
    pub services: ServicesConfiguration
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct LocalConfiguration {
    /// The policy engine configuration.
    pub policy_engine: PolicyEngineConfiguration,
    /// The crypto sidecar configuration.
    pub crypto_sidecar: CryptoSidecarConfiguration
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct ServicesConfiguration {
    /// The AA certificate registry configuration.
    pub aa_cert_registry: AACertificateRegistryConfiguration,
    /// The key management service configuration.
    pub key_management: KeyManagementConfiguration
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct PolicyEngineConfiguration {
    /// The port of the policy engine.
    pub port: String
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct CryptoSidecarConfiguration {
    /// The port of the crypto sidecar.
    pub port: String
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct AACertificateRegistryConfiguration {
    /// The URI of the AA certificate registry.
    pub uri: String
}

#[derive(Clone, Default, Serialize, Deserialize, Debug)]
pub struct KeyManagementConfiguration {
    /// The the key management provider.
    pub provider: String,
    /// The URI of the key management provider.
    pub uri: String
}

impl CommandLineOptions {
    pub fn parse() -> Configuration {
        // Parse the options from the application arguments.
        let options = CommandLineOptions::from_args();

        // Initialize the logger.
        logger::init(options.verbose).unwrap();

        // Parse the configuration file.
        let file = std::fs::File::open(&options.configuration);
        match file {
            Ok(file) => {
                let config: serde_yaml::Result<YamlConfiguration> = serde_yaml::from_reader(file);
                match config {
                    Ok(config) => {
                        return config.sidecar;
                    },
                    Err(err) => {
                        error!("Could not parse the configuration file '{}': {}", &options.configuration, err);
                        std::process::exit(1);
                    }
                }
            }
            Err(e) => {
                error!("Could not open configuration file '{}': {}", &options.configuration, e);
                std::process::exit(1);
            }
        }
    }
}
