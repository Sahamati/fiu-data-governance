# Setting up an Azure Key Vault for managing the CCR keys

First, create a new Azure Key Vault (AKS) by following the steps outlined
[here](https://docs.microsoft.com/en-us/azure/key-vault/general/quick-create-portal).

Next, make sure that your AKS cluster has "Azure Managed Identities" enabled. Read
[here](https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#create-an-aks-cluster-with-managed-identities)
how to create a new AKS cluster with this feature enabled, or [how to
update](https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#update-an-aks-cluster-to-managed-identities)
an existing cluster.

Once your AKS cluster supports managed identities, open the Azure Portal, go to your AKS cluster
resource, click "Properties" under "Settings", and click the link under the "Infrastructure resource
group" section. This will open the AKS cluster resource group. Select the "Virtual machine scale
set" resource and select "Identity" under "Settings". Here, make sure that the "System assigned"
identity has status "On" (if not turn it on). Copy the "Object (principal) ID". You will use it to
configure access to the AKV.

Finally, to enable access to the AKV from the CCR using Azure Managed Identity, follow these steps:
- Access your AKV in Azure Portal and click "Access Policies".
- Make sure that the permission model is set to "Vault access policy".
- Click "Add access policy" and set the "Secret permissions" to allow "Get" and "Set" management operations.
- Then select the principal of your AKS cluster (using the id that you copied above) and click "Add".

The CCR pods in your AKS cluster should now have access to your AKV for managing the CCR keys.
