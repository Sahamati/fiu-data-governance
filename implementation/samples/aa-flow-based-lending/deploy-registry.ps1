param(
  [Switch]$remove
)

# Remove the pod, if it was previously deployed.
kubectl delete -f $PSScriptRoot/k8s/certificate-registry-deployment.yaml --ignore-not-found=true

if ($remove) {
  # Remove the front-end service.
  kubectl delete -f $PSScriptRoot/k8s/certificate-registry-service.yaml --ignore-not-found=true
  exit 0
}

# Deploy the front-end service.
kubectl apply -f $PSScriptRoot/k8s/certificate-registry-service.yaml

# Deploy the pod.
kubectl apply -f $PSScriptRoot/k8s/certificate-registry-deployment.yaml
