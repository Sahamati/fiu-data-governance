# Helper script to deploy on a kind cluster. Useful to setup the local dev environment for the first
# time and then iterate on the containers of interest.

$build = "$PSScriptRoot/../../build"
$samples = "$PSScriptRoot/../../samples"
pwsh $build/build-ccr-init-container.ps1
docker tag ccr-init:latest foo.azurecr.io/ccr-init:latest
kind load docker-image foo.azurecr.io/ccr-init:latest

pwsh $build/build-ccr-proxy.ps1
docker tag ccr-proxy:latest foo.azurecr.io/ccr-proxy:latest
kind load docker-image foo.azurecr.io/ccr-proxy:latest

pwsh $build/build-ccr-sidecar.ps1
docker tag ccr-sidecar:latest foo.azurecr.io/ccr-sidecar:latest
kind load docker-image foo.azurecr.io/ccr-sidecar:latest

pwsh $build/build-depa-services.ps1
docker tag business-rule-engine-service:latest foo.azurecr.io/business-rule-engine-service:latest
kind load docker-image foo.azurecr.io/business-rule-engine-service:latest

docker tag statement-analysis-service:latest foo.azurecr.io/statement-analysis-service:latest
kind load docker-image foo.azurecr.io/statement-analysis-service:latest

docker tag certificate-registry-service:latest foo.azurecr.io/certificate-registry-service:latest
kind load docker-image foo.azurecr.io/certificate-registry-service:latest

docker tag financial-information-user-service:latest foo.azurecr.io/financial-information-user-service:latest
kind load docker-image foo.azurecr.io/financial-information-user-service:latest

docker tag account-aggregator-service:latest foo.azurecr.io/account-aggregator-service:latest
kind load docker-image foo.azurecr.io/account-aggregator-service:latest

pwsh $build/build-crypto-sidecar.ps1
docker tag crypto-sidecar:latest foo.azurecr.io/crypto-sidecar:latest
kind load docker-image foo.azurecr.io/crypto-sidecar:latest

pwsh $build/build-ccr-skr-sidecar.ps1
docker tag ccr-skr-sidecar:latest foo.azurecr.io/ccr-skr-sidecar:latest
kind load docker-image foo.azurecr.io/ccr-skr-sidecar:latest

pwsh $build/build-inmemory-keyprovider.ps1
docker tag inmemory-keyprovider:latest foo.azurecr.io/inmemory-keyprovider:latest
kind load docker-image foo.azurecr.io/inmemory-keyprovider:latest

pwsh $samples/aa-flow-based-lending/deploy-registry.ps1 -k kind -registryUrl foo.azurecr.io

kubectl wait --for=condition=ready pod -l app=certificate-registry --timeout=180s;
kubectl wait --for=condition=ready pod -l app=oci-registry --timeout=180s;

kubectl port-forward service/oci-registry 5000:80 &

pwsh $build/publish-depa-policies-bundle.ps1 -registryUrl localhost:5000

pwsh $samples/aa-flow-based-lending/deploy-ccr.ps1 -k kind -registryUrl foo.azurecr.io

kubectl wait --for=condition=ready pod -l app=business-rule-engine --timeout=180s;
kubectl wait --for=condition=ready pod -l app=statement-analysis --timeout=180s;
kubectl wait --for=condition=ready pod -l app=account-aggregator --timeout=180s;
kubectl wait --for=condition=ready pod -l app=financial-information-user --timeout=180s;

kubectl port-forward service/financial-information-user 8090:8001 &

kubectl port-forward service/account-aggregator 8091:8000 &

python3 ./samples/aa-flow-based-lending/client.py `
--fi ./samples/aa-flow-based-lending/data/transactions.json `
--consent ./samples/aa-flow-based-lending/data/consent.json `
--bre-url "https://business-rule-engine:80/" `
--cr-url "http://certificate-registry:80/" `
--fiu-url "http://localhost:8090/" `
--aa-url "http://localhost:8091"