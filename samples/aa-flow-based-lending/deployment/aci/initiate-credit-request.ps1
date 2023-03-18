$BRE_IP=$(az container show --name conf-business-rule-engine-aci --resource-group $ENV:RESOURCE_GROUP | jq -r .ipAddress.ip)
$BRE_URL="https://" + $BRE_IP + ":8080"

$CR_IP=$(az container show --name certificate-registry-aci --resource-group $ENV:RESOURCE_GROUP | jq -r .ipAddress.ip)
$CR_URL="http://" + $CR_IP + ":8080/"

python3 $PSScriptRoot/../../client.py `
  --fi $PSScriptRoot/../../data/transactions.json `
  --consent $PSScriptRoot/../../data/consent.json `
  --bre-url $BRE_URL --cr-url $CR_URL

