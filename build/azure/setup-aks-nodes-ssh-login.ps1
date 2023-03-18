param(
  [string]$username,
  [string]$cluster_name,
  [string]$resource_group,
  [string]$ssh_public_key_file
)

$ErrorActionPreference = "Stop"

# Retrieve the variables from the Azure subscription.
$cluster_resource_group = $(az aks show --resource-group $resource_group --name $cluster_name --query nodeResourceGroup -o tsv)
$scale_set_name = $(az vmss list --resource-group $cluster_resource_group --query [0].name -o tsv)

# Enable ssh login on the cluster nodes.
$ssh_public_key = Get-Content $ssh_public_key_file
$protected_settings = "{""username"":""$username"", ""ssh_key"":""$ssh_public_key""}" | ConvertTo-Json
az vmss extension set `
  --resource-group $cluster_resource_group `
  --vmss-name $scale_set_name `
  --name VMAccessForLinux `
  --publisher Microsoft.OSTCExtensions `
  --version 1.4 `
  --protected-settings $protected_settings

# Update the cluster nodes.
az vmss update-instances --instance-ids '*' --resource-group $cluster_resource_group --name $scale_set_name
