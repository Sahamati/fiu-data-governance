param(
  [Switch]$genOnly
)

. $PSScriptRoot\helpers.ps1

$CERTIFICATE_REGISTRY_IP=$(az container show --name certificate-registry-aci --resource-group $ENV:RESOURCE_GROUP | jq -r .ipAddress.ip)
$env:CERTIFICATE_REGISTRY_URL="http://" + $CERTIFICATE_REGISTRY_IP + ":8080"

# Generate values to be inserted in the ARM template and the ccepolicy. We have to escape the json
# content once for cce policy input and twice for ARM template input.
$POLICY_DATA_RAW_STRING= `
  (Get-Content $PSScriptRoot/../../config/policy-data-config.json `
   | jq '(.services.aa_cert_registry.uri) |= env.CERTIFICATE_REGISTRY_URL') | `
   ConvertFrom-Json | ConvertTo-Json -Compress -Depth 10
$env:POLICY_DATA_CCE_POLICY = $POLICY_DATA_RAW_STRING -replace '"', '\"'
$POLICY_DATA_ARM = $POLICY_DATA_RAW_STRING -replace '"', '\\""'

# Generate ccepolicy input.
Get-Content $PSScriptRoot/statement-analysis-policy-in.template.json | `
  envsubst '$IMAGE_PATH_PREFIX $POLICY_DATA_CCE_POLICY $BUNDLE_SERVICE_CREDENTIALS_SCHEME' `
 > $PSScriptRoot/statement-analysis-policy-in.json

 if ($genOnly) {
  Write-Host "POLICY_DATA_ARM: $POLICY_DATA_ARM"
  Write-Host "POLICY_DATA_CCE_POLICY: $env:POLICY_DATA_CCE_POLICY"
  exit 0
}

 # Start deployment.
$CCE_POLICY=(az confcom acipolicygen -i $PSScriptRoot/statement-analysis-policy-in.json | tr -d '\n')

$ACI_PARAMETERS='{\"containerRegistry\": {\"value\":\"' + $ENV:CONTAINER_REGISTRY `
  + '\"}, \"containerRegistryUsername\": {\"value\":\"' + $ENV:CONTAINER_REGISTRY_USERNAME `
  + '\"}, \"containerRegistryPassword\": {\"value\":\"' + $ENV:CONTAINER_REGISTRY_PASSWORD `
  + '\"}, \"userAssignedIdentityId\": {\"value\":\"' + $ENV:USER_MI_ID `
  + '\"}, \"imagePathPrefix\": {\"value\":\"' + $ENV:IMAGE_PATH_PREFIX `
  + '\"}, \"ccePolicy\": {\"value\":\"' + $CCE_POLICY `
  + '\"}, \"policyData\": {\"value\":\"' + $POLICY_DATA_ARM `
  + '\"}, \"bundleServiceUrl\": {\"value\":\"' + $ENV:BUNDLE_SERVICE_URL `
  + '\"}, \"bundleServiceCredentialsScheme\": {\"value\":\"' + $ENV:BUNDLE_SERVICE_CREDENTIALS_SCHEME `
  + '\"}, \"bundleServiceCredentialsToken\": {\"value\":\"' + $ENV:BUNDLE_SERVICE_CREDENTIALS_TOKEN `
  + '\"}, \"dnsNameLabel\": {\"value\":\"' + $ENV:SA_DNS_LABEL_NAME `
  + '\"}}'

if (!(NeedsExtraEscaping)) {
  $ACI_PARAMETERS = ($ACI_PARAMETERS  -replace '\\"', '"')
  $ACI_PARAMETERS = ($ACI_PARAMETERS  -replace '\\"', '\')
}

az deployment group create --resource-group $ENV:RESOURCE_GROUP `
  --template-file $PSScriptRoot/statement-analysis-deployment.json `
  --parameters $ACI_PARAMETERS `
  --verbose
