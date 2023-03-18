# Confidential Clean Room (CCR) Reference Implementation

The CCR reference implementation is provided here **As-Is** as **beta** to showcase how CCRs can be
implemented for DEPA according to the [architecture guidelines](../guidelines/README.md). Please
note that this is **work-in-progress** and should **not be used in production**.

Please also note that although the CCR architecture itself is **generic** and **vendor-neutral**,
this reference implementation currently uses Azure for deployment and for the implementation of its
backend services (e.g., for key management), but each such instance has an accompanying interface to
allow alternative implementations.

We actively welcome contributions and feedback from the community.

## Components

The reference CCR implementation consists of the following components.

|||
|---|---|
| [Envoy proxy](https://www.envoyproxy.io/) | Network proxy that intercepts all communications to and from application containers, and forward requests and responses to the CCR sidecar. |
| [CCR sidecar](cmd/ccr-sidecar) | Container responsible for implementing the gRPC server to handle request/response messages from Envoy and inturn invoke the OPA engine to process the same. |
| [OPA engine](https://www.openpolicyagent.org/) | OPA policy engine (embedded in the CCR sidecar) which checks that all ingress and egress traffic satisfies a pre-defined policy. |
| [OPA policy bundle](../samples/aa-flow-based-lending/policies) | OPA policy bundle responsible for implementing the [CCR API](docs/api.md), key management and decryption of data from the AA, as well as interfacing with any locally hosted CCR infrastructure container (i.e., the crypto and SKR sidecars). |
| [Crypto sidecar](https://github.com/Sahamati/rahasya/tree/dd2553f036c9935c23f8b7708c9957afbeebc003) | Container that implements with Diffie-Hellman Key exchange as per the Account Aggregator specification. |
| [SKR sidecar](https://github.com/microsoft/confidential-sidecar-containers) | The SKR container implements an endpoint to request attestation tokens from the Microsoft Azure Attestation Service (MAA). |
| [Init container](../build/docker/Dockerfile.init) | Container that sets up IP tables to route traffic to the network proxy and firewall. |

This repository also contains a [sample application](../samples/aa-flow-based-lending) that shows how
these components can be deployed along with the application's business logic. The sample is a simple
flow-based lending service which receives bank statements from a mock FIP through the AA, and
computes a credit score, which the FIU may used to determine the terms of the loan. 

## CCR API

The CCR API is described [here](api.md).

## Get started
First, follow [these instructions](setup.md) to setup your local development environment, build
the CCR infrastructure, as well as setup an Azure Kubernetes Service (AKS) cluster for deployment.
You are now ready to build, deploy and run containers inside a CCR.

## Sample scenario
You can now deploy one of the following sample scenarios. 

- [Confidential flow-based lending in the AA ecosystem](../samples/aa-flow-based-lending/README.md)
