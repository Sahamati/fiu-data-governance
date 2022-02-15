param(
  [Switch]$remove
)

# Remove the CCR pods, if they were previously deployed.
kubectl delete -f $PSScriptRoot/k8s/statement-analysis-deployment.yaml --ignore-not-found=true
kubectl delete -f $PSScriptRoot/k8s/business-rule-engine-deployment.yaml --ignore-not-found=true

# Remove the CCR proxy configuration map.
kubectl delete cm ccr-proxy-config --ignore-not-found=true

# Remove the CCR sidecar configuration map.
kubectl delete cm bre-ccr-sidecar-config --ignore-not-found=true
kubectl delete cm sa-ccr-sidecar-config --ignore-not-found=true

# Remove the CCR OPA policy configuration map.
kubectl delete cm ccr-policy --ignore-not-found=true

if ($remove) {
  # Remove the CCR front-end services.
  kubectl delete -f $PSScriptRoot/k8s/statement-analysis-service.yaml --ignore-not-found=true
  kubectl delete -f $PSScriptRoot/k8s/business-rule-engine-service.yaml --ignore-not-found=true
  exit 0
}

# Create the CCR OPA policy configuration map.
kubectl create cm ccr-policy `
  --from-file=$PSScriptRoot/policies/policy.rego `
  --from-file=$PSScriptRoot/policies/helpers.rego

# Create the CCR sidecar configuration map.
kubectl create cm bre-ccr-sidecar-config --from-file=$PSScriptRoot/config/business-rule-engine/ccr-sidecar-config.yaml
kubectl create cm sa-ccr-sidecar-config --from-file=$PSScriptRoot/config/statement-analysis/ccr-sidecar-config.yaml

# Create the CCR proxy configuration map.
kubectl create cm ccr-proxy-config --from-file=$PSScriptRoot/config/ccr-proxy-config.yaml

# Deploy the CCR front-end services.
kubectl apply -f $PSScriptRoot/k8s/statement-analysis-service.yaml
kubectl apply -f $PSScriptRoot/k8s/business-rule-engine-service.yaml

# Deploy the CCR pods.
kubectl apply -f $PSScriptRoot/k8s/statement-analysis-deployment.yaml
kubectl apply -f $PSScriptRoot/k8s/business-rule-engine-deployment.yaml
