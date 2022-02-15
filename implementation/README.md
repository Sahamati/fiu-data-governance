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
| [CCR sidecar](src/ccr-sidecar) | Container responsible for implementing the [CCR API](docs/api.md), key management and decryption of data from the AA, as well as interfacing with any locally hosted CCR infrastructure container (i.e., the crypto and OPA sidecars). |
| [Crypto sidecar](https://github.com/Sahamati/rahasya/tree/dd2553f036c9935c23f8b7708c9957afbeebc003) | Container that implements with Diffie-Hellman Key exchange as per the Account Aggregator specification. |
| [OPA sidecar](https://www.openpolicyagent.org/) | Container which checks that all ingress and egress traffic satisfies a pre-defined policy. |
| [Init container](ci/docker/Dockerfile.init) | Container that sets up IP tables to route traffic to the network proxy and firewall. |

This repository also contains a [sample application](samples/aa-flow-based-lending) that shows how
these components can be deployed along with the application's business logic. The sample is a simple
flow-based lending service which receives bank statements from a mock FIP through the AA, and
computes a credit score, which the FIU may used to determine the terms of the loan. 

## CCR API

The CCR API is described [here](docs/api.md).

## Get started

First, follow [these instructions](docs/setup.md) to setup your local development environment, build
the CCR infrastructure, as well as setup an Azure Kubernetes Service (AKS) cluster for deployment.
You are now ready to build, deploy and run containers inside a CCR.

Next, check out the [sample scenario](#sample-scenario).

## Sample scenario

Check out the sample scenario:

- [Confidential flow-based lending in the AA ecosystem](samples/aa-flow-based-lending)
