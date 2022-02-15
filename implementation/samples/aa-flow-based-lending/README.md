# Sample: Confidential flow-based lending in the AA ecosystem

This sample consists of 5 services that interact with each other to process a scoring request:

- Account Aggregator (AA)
- Financial Information User (FIU)
- Business Rule Engine (BRE)
- Statements Analysis (SA)
- Certificate Registry (CR)

The Account Aggregator (AA) and Financial Information User (FIU) services run locally on Docker
containers. They are considered _untrusted_ and are not part of the CCR. Note that for simplicity,
the AA is also simulating a Financial Information Provider (FIP) in this sample.

The Business Rule Engine (BRE) and Statements Analysis (SA) services are also considered
_untrusted_, but they _run inside a CCR_ deployed on an AKS cluster. The CCR deployment ensures that
these two services are sandboxed and adhere to the configured [ingress and egress
policies](policies).

Finally, the Certificate Registry (CR) service is also deployed on the same AKS cluster for
simplicity, but is trusted and runs outside of a CCR. This service mocks requests to Sahamati for
the purposes of verifying the signed consent.

There is also a client script that starts the workflow.

_Please note that all services in this sample are very basic (with certain logic hardcoded), as
their purpose is to just serve as an example of using CCRs, and not showing a production end-to-end
flow-based lending workflow._

## Prerequisites

If you have not already followed [the CCR setup instructions](../../docs/setup.md), please do so
before proceeding.

You must create an [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/) (AKV)
and configure it as the key management service for the CCR. You can learn how to do this
[here](../../docs/azure/akv.md).

## Building the service containers

To build the service containers run the following script in `powershell`:
```
cd $REPOSITORY_ROOT_PATH/implementation
./ci/build-depa-services.ps1
```

To prepare the 3 containers (BRE, SA and CR) that will be deployed to AKS, tag the Docker images and
push them to [ACR](https://azure.microsoft.com/services/container-registry/) from `powershell`:
```powershell
$acrLoginServer="<ACR_LOGIN_SERVER>"
docker login $acrLoginServer
docker tag business-rule-engine-service:latest $acrLoginServer/business-rule-engine-service:latest
docker tag statement-analysis-service:latest $acrLoginServer/statement-analysis-service:latest
docker tag certificate-registry-service:latest $acrLoginServer/certificate-registry-service:latest
docker push $acrLoginServer/business-rule-engine-service:latest
docker push $acrLoginServer/statement-analysis-service:latest
docker push $acrLoginServer/certificate-registry-service:latest
```

## Building the cryptography sidecar container

This sample uses the Sahamati `rahasya` crypto container that is available
[here](https://github.com/Sahamati/rahasya/tree/V1.2).

If you have not done so already, you must first sync and update the `rahasya`
[submodule](..\external\rahasya), as follows:
```
git submodule sync --recursive
git submodule update --init --recursive
```

You are now ready to build the crypto sidecar container by running the following script in
`powershell`:
```
./ci/build-crypto-sidecar.ps1
```

Next, tag the image and push it to ACR from `powershell`:
```powershell
docker tag crypto-sidecar:latest $acrLoginServer/crypto-sidecar:latest
docker push $acrLoginServer/crypto-sidecar:latest
```

## Set appropriate URIs in the configuration and deployment files

Before deploying the services to AKS, you must first edit the following configuration and deployment
YAML files to replace any placeholder `foo` values in the URIs with the appropriate ones from your
setup.

The YAML files that need editing are the following:
- [CCR sidecar configuration for BRE](./config/business-rule-engine/ccr-sidecar-config.yaml)
- [CCR sidecar configuration for SA](./config/statement-analysis/ccr-sidecar-config.yaml)
- [AKS deployment configuration for BRE](./k8s/business-rule-engine-deployment.yaml)
- [AKS deployment configuration for SA](./k8s/statement-analysis-deployment.yaml)
- [AKS deployment configuration for CR](./k8s/certificate-registry-deployment.yaml)

## Deploy the Certificate Registry (CR) to AKS

Deploy the CR service to AKS by running the following script in `powershell`:
```
./samples/aa-flow-based-lending/deploy-registry.ps1
```

**Note:** Running the above script will replace any registry that has already been deployed.

## Deploy the CCRs to AKS

Assuming you have completed the instructions above, you can now deploy the CCRs to AKS by running
the following script in `powershell`:
```
./samples/aa-flow-based-lending/deploy-ccr.ps1
```

**Note:** Running the above script replaces any already deployed CCRs, as well as any installed
configuration and policy files.

Wait until the pod(s) have been successfully deployed. To find out, run the following command:
```sh
kubectl get pods --watch
```
Once the status of the pod(s) changes to `Running`, do `ctrl+c` and you are good to go!

To see the business logic container logs, run:
```sh
kubectl logs -l app=statement-analysis -c statement-analysis-service --tail=-1
kubectl logs -l app=business-rule-engine -c business-rule-engine-service --tail=-1
```

To see the CCR proxy container logs, run:
```sh
kubectl logs -l app=statement-analysis -c ccr-proxy --tail=-1
kubectl logs -l app=business-rule-engine -c ccr-proxy --tail=-1
```

To see the CCR sidecar container logs, run:
```sh
kubectl logs -l app=statement-analysis -c ccr-sidecar --tail=-1
kubectl logs -l app=business-rule-engine -c ccr-sidecar --tail=-1
```

To see the CCR policy engine container logs, run:
```sh
kubectl logs -l app=statement-analysis -c policy-engine --tail=-1
kubectl logs -l app=business-rule-engine -c policy-engine --tail=-1
```

To see the CCR crypto sidecar container logs, run:
```sh
kubectl logs -l app=statement-analysis -c crypto-sidecar --tail=-1
kubectl logs -l app=business-rule-engine -c crypto-sidecar --tail=-1
```

To see the certificate registry (CR) container logs, run:
```sh
kubectl logs -l app=certificate-registry --tail=-1
```

## Run the workflow

First, run the AA, FIU and crypto client containers locally using Docker compose:
```sh
docker compose -f ./samples/aa-flow-based-lending/docker-compose.yml up
```

You can now invoke the following client python script, which setups the initial state of the AA and
FIU containers, and then runs the workflow:
```sh
$breIP=(kubectl get svc business-rule-engine -o json | ConvertFrom-Json).status.loadBalancer.ingress.ip
$crIP=(kubectl get svc certificate-registry -o json | ConvertFrom-Json).status.loadBalancer.ingress.ip
python3 samples/aa-flow-based-lending/client.py --fi samples/aa-flow-based-lending/data/transactions.json --consent samples/aa-flow-based-lending/data/consent.json --bre-url "http://$($breIP):80/" --cr-url "http://$($crIP):80/"
```

To get the logs from the local containers, run:
```sh
docker compose -f ./samples/aa-flow-based-lending/docker-compose.yml logs --since 1m
```
where `1m` can be replaced with any time period.

If you want to print the logs from a single container only, add the name of the container to the end
of the above command: `financial-information-user` or `account-aggregator`.

## Cleaning up the AKS deployment

To clean up the deployment on the AKS, run the following two scripts in `powershell`:
```
./samples/aa-flow-based-lending/deploy-registry.ps1 -remove
./samples/aa-flow-based-lending/deploy-ccr.ps1 -remove
```

This will remove the deployed CCR services and registry, as well as remove any installed
CCR configuration and policy files.
