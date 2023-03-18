# CCR Sidecar
This sidecar implements Envoy's [External Processing filter](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/ttp_filters/ext_proc_filter) and in turn invokes the OPA filter. The OPA filter would then process a set of well known rules for the request and response messages messages. See [OPA filter](../../internal/filter/opa/README.md) for more details.

## Local Development
To quickly get started and have an end to end development setup that builds and deploys all components for the AA scenario on your local machine, setup a Kind cluster (see steps [here](https://kind.sigs.k8s.io/docs/user/quick-start/) to install it) and then do the following in `powershell`:
```
# Create a Kind cluster
kind create cluster

# Build and deploy the AA scenario
./samples/aa-flow-based-lending/deploy-on-kind.ps1
```

To build only the CCR sidecar image using a local Docker container, run in `powershell`:
```
./build/build-ccr-sidecar.ps1
```

To build and launch/debug the CCR sidecar locally from your machine just hit `F5` in VSCode.

## Configuration
The configuration file path is specified with the -c command line argument:
```bash
./ccr-sidecar -c config.json
```

#### Example

```json
{
  "host":"127.0.0.1",
  "port":8281,
  "local":{
    "policy_engine":{
      "bundle_resource":"ghcr.io/${ORGANIZATION}/${REPOSITORY}:[${TAG}|@{DIGEST}]",
      "bundle_service_url":"https//ghcr.io",
      "data":{
        "key1":"value1",
        "key2":{
          "key3":{
            "key4":"value4"
          }
        },
        "...":"..."
      }
    }
  }
}
```

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `host` | `string` | No (default: `127.0.0.1`) | The host name using which the sidecar starts the gRPC server. |
| `port` | `int` | No (default: `8281`) | The port on which the sidecar starts the gRPC server. |

### local/policy_engine

`local/policy_engine` section is used to specify the OPA policy bundle configuration:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `bundle_resource` | `string` | Yes | Resource path to use to download bundle from the OCI registry service. |
| `bundle_service_url` | `string` | No (default: `https://<hostname>` where `hostname` is extracted from bundle_resource value) | Base URL to contact the OCI registry service with. |
| `data` | `JSON` | No | A JSON object that is passed in as-is into the OPA policy engine and exposed under the `data` virtual document. This can be used to specify any configuration values that the rules logic might need. |

