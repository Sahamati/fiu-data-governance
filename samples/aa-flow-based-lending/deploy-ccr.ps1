param(
  [Switch]$remove,
  [ValidateSet('kind', 'aks')]
  [string]$k = "aks",
  [string]$registryUrl = $null
)

if ($null -ne $registryUrl) {
  $env:IMAGE_PATH_PREFIX=$registryUrl
}

if (!$remove -and ($null -eq $env:IMAGE_PATH_PREFIX -or $env:IMAGE_PATH_PREFIX -eq "")) {
  Write-Host "The ACR url where the container images are hosted must be specified. Pass the same using: -registryUrl <foo.azurecr.io>"
  exit 1
}

$services = @(
  "business-rule-engine",
  "statement-analysis",
  "account-aggregator",
  "financial-information-user"
)

# Remove the CCR pods, if they were previously deployed.
foreach ($service in $services) {
  kubectl delete -f $PSScriptRoot/deployment/k8s/base/$service/$service-deployment.yaml --ignore-not-found=true --wait
}

# Remove the CCR proxy configuration map.
kubectl delete cm ccr-proxy-config --ignore-not-found=true --wait

if ($remove) {
  # Remove the CCR front-end services.
  foreach ($service in $services) {
    kubectl delete -f $PSScriptRoot/deployment/k8s/base/$service/$service-service.yaml --ignore-not-found=true
  }  exit 0
}

# Create the CCR proxy configuration map.
kubectl create cm ccr-proxy-config --from-file=$PSScriptRoot/config/ccr-proxy-config.yaml

# Remove the policy bundle token secret.
kubectl delete secret policy-bundle-credentials --ignore-not-found=true

if ($env:BUNDLE_SERVICE_CREDENTIALS_TOKEN -ne "") {
  # Create the policy bundle token secret.
  kubectl create secret generic policy-bundle-credentials --from-literal=token=$env:BUNDLE_SERVICE_CREDENTIALS_TOKEN
}

$kustomization_directory = "overlays/" + $k

# Run the template thru envsubst to create the kustomization.yaml with env variable value substitution.
foreach ($service in $services) {
  if (test-path $PSScriptRoot/deployment/k8s/$kustomization_directory/$service/kustomization.yaml.template) {
    Get-Content $PSScriptRoot/deployment/k8s/$kustomization_directory/$service/kustomization.yaml.template | `
    envsubst '$IMAGE_PATH_PREFIX $BUNDLE_SERVICE_URL $BUNDLE_SERVICE_CREDENTIALS_SCHEME' > $PSScriptRoot/deployment/k8s/$kustomization_directory/$service/kustomization.yaml
  }
}

# Deploy the CCR front-end services and the pods.
foreach ($service in $services) {
  kubectl apply -k $PSScriptRoot/deployment/k8s/$kustomization_directory/$service
}
