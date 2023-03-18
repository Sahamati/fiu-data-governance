# Building the CCR infrastructure

## Table of Contents
1. [Prerequisites](#Prerequisites)
1. [Building the CCR init container](#Building-the-CCR-init-container)
1. [Building the CCR sidecar container](#Building-the-CCR-sidecar-container)
1. [Building the CCR secure key release (SKR) sidecar container](#Building-the-CCR-secure-key-release-SKR-sidecar-container)
1. [Building the OPA policy bundle](#Building-the-OPA-policy-bundle)
1. [Publishing the CCR container images to a container registry](#Publishing-the-CCR-container-images-to-a-container-registry)
1. [Deploying a CCR to a Kubernetes cluster](#Deploying-a-CCR-to-a-Kubernetes-cluster)
1. [Policy enforcement through the Open Policy Agent (OPA)](#Policy-enforcement-through-the-Open-Policy-Agent-OPA)

## Prerequisites

All scripts are written in
[PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/overview),
so for Linux, follow [these
instructions](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux)
to install PowerShell. Once its installed, you can run the following command to start the shell:
```sh
pwsh
```

If you do not have [Docker](https://www.docker.com/products/docker-desktop) already installed, make
sure to install it. Because most of the code builds and runs on Linux containers, you can use Docker
to develop directly on your local Linux machine without worrying about installing too
many dependencies. If you are using Windows then using Ubuntu via [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) to setup the linux environment is recommended.

## Building the CCR init container

To build the CCR init container using `docker` run the following script in `powershell`:
```
./build/build-ccr-init-container.ps1
```

## Building the CCR proxy container

To build the CCR proxy container using `docker` run the following script in `powershell`:
```
./build/build-ccr-proxy.ps1
```

## Building the CCR sidecar container

To build the CCR sidecar container using `docker` run the following script in `powershell`:
```
./build/build-ccr-sidecar.ps1
```

## Building the CCR secure key release (SKR) sidecar container

To build the CCR SKR container using `docker` run the following script in `powershell`:
```
./build/build-ccr-skr-sidecar.ps1
```

## Building the OPA policy bundle

To publish the policy bundle that is used by the CCR policy engine you need to install `oras` cli. Run the following script as root:
```
./build/install-oras.ps1
```

## Publishing the CCR container images to a container registry

To publish the locally built CCR container images, you need a container registry account, such as
with [Azure Container Registry](https://azure.microsoft.com/services/container-registry/) (ACR).

Once you have access to such an account, first login to the registry using `docker` in `powershell`:
```powershell
$acrLoginServer="<ACR_LOGIN_SERVER>"
docker login $acrLoginServer
```

Next, tag and push the container images:
```powershell
./build/push-ccr-containers.ps1
```

## Policy enforcement through the Open Policy Agent (OPA)

CCRs use the [Open Policy Agent](https://www.openpolicyagent.org/) (OPA) to enforce policies on the
sandboxed business logic containers. Policies can be authored using the
[Rego](https://www.openpolicyagent.org/docs/latest/policy-language/) declarive policy language. OPA
is embedded as a libray in the CCR that is running alongside the Envoy proxy. When a request/response flows through
the Envoy proxy, the CCR sidecar calls the OPA engine to check if the request/response can
be authorized or not. See [OPA filter](../internal/filter/opa/README.md) for more details.

**Optional:** To help author policies in Rego using VS Code, you can install the [Open Policy Agent
extension](https://marketplace.visualstudio.com/items?itemName=tsandall.opa). This extension
provides syntax checking, highlighting, and a bunch of other useful features for `.rego` policy
files.
