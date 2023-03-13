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

# Remove the pod, if it was previously deployed.
kubectl delete -f $PSScriptRoot/deployment/k8s/base/certificate-registry/certificate-registry-deployment.yaml --ignore-not-found=true --wait
kubectl delete -f $PSScriptRoot/deployment/k8s/base/oci-registry/oci-registry-deployment.yaml --ignore-not-found=true --wait

if ($remove) {
  # Remove the front-end service.
  kubectl delete -f $PSScriptRoot/deployment/k8s/base/certificate-registry/certificate-registry-service.yaml --ignore-not-found=true
  kubectl delete -f $PSScriptRoot/deployment/k8s/base/oci-registry/oci-registry-service.yaml --ignore-not-found=true
  exit 0
}

$kustomization_directory = "overlays/" + $k

if (test-path $PSScriptRoot/deployment/k8s/$kustomization_directory/certificate-registry/kustomization.yaml.template) {
  Get-Content $PSScriptRoot/deployment/k8s/$kustomization_directory/certificate-registry/kustomization.yaml.template | `
  envsubst '$IMAGE_PATH_PREFIX' > $PSScriptRoot/deployment/k8s/$kustomization_directory/certificate-registry/kustomization.yaml
}

  # Deploy the front-end service and the pod.
kubectl apply -k $PSScriptRoot/deployment/k8s/$kustomization_directory/certificate-registry
if ($k -eq "kind") {
  kubectl apply -k $PSScriptRoot/deployment/k8s/$kustomization_directory/oci-registry
}