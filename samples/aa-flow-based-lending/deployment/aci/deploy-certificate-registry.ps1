. $PSScriptRoot\helpers.ps1

$ACI_PARAMETERS='{\"containerRegistry\": {\"value\":\"' + $ENV:CONTAINER_REGISTRY `
  + '\"}, \"containerRegistryUsername\": {\"value\":\"' + $ENV:CONTAINER_REGISTRY_USERNAME `
  + '\"}, \"containerRegistryPassword\": {\"value\":\"' + $ENV:CONTAINER_REGISTRY_PASSWORD `
  + '\"}, \"imagePathPrefix\": {\"value\":\"' + $ENV:IMAGE_PATH_PREFIX `
  + '\"}, \"dnsNameLabel\": {\"value\":\"' + $ENV:CR_DNS_LABEL_NAME `
  + '\"}}'

if (!(NeedsExtraEscaping)) {
  $ACI_PARAMETERS = ($ACI_PARAMETERS  -replace '\\"', '"')
}

$ACI_PARAMETERS
az deployment group create --resource-group $ENV:RESOURCE_GROUP `
  --template-file $PSScriptRoot/certificate-registry-deployment.json `
  --parameters $ACI_PARAMETERS `
  --verbose
  