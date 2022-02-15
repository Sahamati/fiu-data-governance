# Building the CCR infrastructure

## Prerequisites

All scripts are written in
[PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/overview) to work cross-platform,
so if you are on Linux, follow [these
instructions](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux)
to install PowerShell. Once its installed, you can run the following command to start the shell:
```sh
pwsh
```

If you do not have [Docker](https://www.docker.com/products/docker-desktop) already installed, make
sure to install it. Because most of the code builds and runs on Linux containers, you can use Docker
to develop directly on your local Windows or Linux machine without worrying about installing too
many dependencies.

## Building the CCR init container

To build the CCR init container using `docker` run the following script in `powershell`:
```
cd $REPOSITORY_ROOT_PATH/implementation
./ci/build-ccr-init-container.ps1
```

## Building the CCR sidecar container

To build the CCR sidecar container using `docker` run the following script in `powershell`:
```
./ci/build-ccr-sidecar.ps1
```

Alternatively, to build the sidecar from your command line (e.g. for local deployment or debugging),
first install Rust (or update to the latest version) by running the following script in
`powershell`:
```
./ci/install-rust.ps1
```

Next, download the latest version of the protobuf files used by the CCR sidecar by running the
following script in `powershell`:
```
./src/ccr-sidecar/proto/sync-proto.ps1
```

Now you are ready to build the sidecar in `powershell`:
```
./src/ccr-sidecar/build.ps1
```

## Publishing the CCR container images to a container registry

To publish the locally built CCR container images, you need a container registry account, such as
with [Azure Container Registry](https://azure.microsoft.com/services/container-registry/) (ACR).

Once you have access to such an account, first login to the registry using `docker` in `powershell`:
```powershell
$acrLoginServer="<ACR_LOGIN_SERVER>"
docker login $acrLoginServer
```

Next, tag the container images in `powershell`:
```powershell
docker tag ccr-init:latest $acrLoginServer/ccr-init:latest
docker tag ccr-sidecar:latest $acrLoginServer/ccr-sidecar:latest
```

Finally, you can now push the container images to ACR in `powershell`:
```powershell
docker push $acrLoginServer/ccr-init:latest
docker push $acrLoginServer/ccr-sidecar:latest
```

## Deploying a CCR to a Kubernetes cluster

If you want to deploy a CCR on a Kubernetes cluster on Azure (AKS), follow [these
instructions](azure/aks.md).

## Policy enforcement through the Open Policy Agent (OPA) sidecar

CCRs use the [Open Policy Agent](https://www.openpolicyagent.org/) (OPA) to enforce policies on the
sandboxed business logic containers. Policies can be authored using the
[Rego](https://www.openpolicyagent.org/docs/latest/policy-language/) declarive policy language. OPA
is injected as a sidecar container alongside the Envoy proxy. When a request/response flows through
the Envoy proxy, the confidential sidecar calls the OPA sidecar to check if the request/response can
be authorized or not.

**Optional:** To help author policies in Rego using VS Code, you can install the [Open Policy Agent
extension](https://marketplace.visualstudio.com/items?itemName=tsandall.opa). This extension
provides syntax checking, highlighting, and a bunch of other useful features for `.rego` policy
files.
