param(
  [string]$cluster_name,
  [string]$container_registry_name,
  [string]$resource_group,
  [string]$location
)

$ErrorActionPreference = "Stop"

# Create a resource group for AKS.
az group create --name $resource_group --location $location

# Create an AKS cluster on the resource group.
az aks create --resource-group $resource_group --name $cluster_name --node-count 3 --generate-ssh-keys

# Create an Azure Container Registry (ACR) for AKS on the resource group.
az acr create --resource-group $resource_group --name $container_registry_name --sku Basic
az aks update -n $cluster_name -g $resource_group --attach-acr $container_registry_name

# Configure kubectl to connect to the AKS cluster.
az aks get-credentials --resource-group $resource_group --name $cluster_name
