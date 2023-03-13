# Setting up an AKS for CCR deployment on Azure

First, [install the Azure CLI tool](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).

If you already have access to a Kubernetes cluster on Azure (AKS), then use the `az` CLI tool to
configure `kubectl` with access to your cluster:
```sh
$SUBSCRIPTION="<Your Azure subscription>"
$CLUSTER_NAME="<Your AKS cluster name>"
$RESOURCE_GROUP="<Your AKS cluster resource group>"

az login
az account set --subscription $SUBSCRIPTION
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --admin
```

Else, follow the instructions below to deploy a new AKS cluster.

You can either use the command line to run our automated script, or manually perform the deployment
steps on the Azure portal as described
[here](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough).

To automatically deploy a new AKS cluster, as well as the required [Azure Container
Registry](https://azure.microsoft.com/en-us/services/container-registry/) (ACR), via command line,
first login to Azure and set your active subscription as follows:
```sh
az login
az account set --subscription $SUBSCRIPTION
```

You can now deploy a new AKS cluster by running the following script (substituting the input
parameters with your own) in `powershell`:
```sh
./build/azure/setup-aks.ps1 $CLUSTER_NAME $CONTAINER_REGISTRY_NAME $RESOURCE_GROUP $LOCATION
```

For example, you could do:
```
./build/azure/setup-aks.ps1 myAKSCluster myacr myResourceGroup eastus
```

**NOTE:** The script can take a few minutes to complete the deployment.

If you want to deploy the AKS cluster manually from the Azure Portal, then create a simple 3 node
cluster, as described in these
[instructions](https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough).

Next, attach an Azure Container Registry (ACR) where your docker containers are stored, following
the steps listed [here](https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-prepare-acr).
Make sure that your AKS cluster can authenticate to the ACR you created, else it will not be able to
pull docker images during pod deployment (you will get the `ImagePullBackOff` status when running
`kubectl get pods`). This can be done as follows:
```sh
$CONTAINER_REGISTRY_NAME="<Your ACR registry name>"

az aks update -n $CLUSTER_NAME -g $RESOURCE_GROUP --attach-acr $CONTAINER_REGISTRY_NAME
```

## Setting up the AKS cluster nodes for sandboxing

If you do not have an existing RSA key (or wish to create a new key), run the following command to
create a new RSA key.
```sh
ssh-keygen -t RSA
```

Next, run the following commands to enable ssh login on the cluster nodes:
```sh
$USERNAME="azureuser" # Change it if you wish.
$SSH_PUBLIC_KEY_FILE="<Path to your SSH public key file>"

./build/azure/setup-aks-nodes-ssh-login.ps1 $USERNAME $CLUSTER_NAME $RESOURCE_GROUP $SSH_PUBLIC_KEY_FILE
```

Finally install the [seccomp](https://en.wikipedia.org/wiki/Seccomp) policy on each of the nodes by
running the following script:
```sh
$SSH_PRIVATE_KEY_FILE="<Path to your SSH private key file>"

./build/config/seccomp/setup-seccomp-k8s.ps1 $USERNAME $SSH_PRIVATE_KEY_FILE
```
