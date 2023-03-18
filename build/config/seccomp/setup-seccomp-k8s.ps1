param(
  [Parameter(Mandatory = $true, HelpMessage = 'Enter SSH login username', Position = 0)]
  [string]$username,
  [Parameter(Mandatory = $true, HelpMessage = 'Enter path to SSH private key file', Position = 1)]
  [string]$key_file
)

$ErrorActionPreference = "Stop"
if (!$(Test-Path $key_file)) {
  Write-Error "File $key_file does not exist."
  exit 1
}

$SECCOMP_FILE = "seccomp-policy.json"

# Get the IP addresses of all Kubernetes cluster nodes.
$NODE_IPs = $(kubectl get nodes -o=jsonpath='{.items[*].status.addresses[1].address}')

foreach ($IP in $NODE_IPS -split " ") { 
	Write-Output "Installing seccomp at Kubernetes cluster node with ip '$IP'."
}

kubectl create ns seccomp-ssh-ns
kubectl create secret generic secret-ssh-key -n seccomp-ssh-ns --from-file=ssh-key=${KEY_FILE}

Write-Output @"
apiVersion: v1
kind: Pod
metadata:
  name: sshpod
  namespace: seccomp-ssh-ns
spec:
  containers:
  - name: sshpod
    image: mcr.microsoft.com/aks/fundamental/base-ubuntu:v0.0.11
    command: ["tail"]
    args: ["-f","/dev/null"]
    volumeMounts:
    - name: ssh-key
      mountPath: "/etc/ssh-key"
      readOnly: true
    env:
    - name: NODE_IPs
      value: $(echo $NODE_IPs)
    - name: AZURE_USER 
      value: $(echo $username)
    - name: SECCOMP_FILE
      value: $(echo $SECCOMP_FILE)

  volumes:
  - name: ssh-key
    secret:
      secretName: secret-ssh-key
"@ | kubectl apply -f -

if ($IsWindows) {
  # We are using the relative path due to known issue with Windows paths.
  # See: https://github.com/kubernetes/kubernetes/issues/101985
  $seccomp_file_resolved = Get-Item $PSScriptRoot/$SECCOMP_FILE | Resolve-Path -Relative
  $script_path_resolved = Get-Item $PSScriptRoot/pod-script.sh | Resolve-Path -Relative
} else {
  $seccomp_file_resolved = "$PSScriptRoot/$SECCOMP_FILE"
  $script_path_resolved = "$PSScriptRoot/pod-script.sh"
}

kubectl wait --for=condition=Ready -n seccomp-ssh-ns pod/sshpod;
kubectl cp $seccomp_file_resolved seccomp-ssh-ns/sshpod:/$SECCOMP_FILE;
kubectl cp $script_path_resolved seccomp-ssh-ns/sshpod:/pod-script.sh;
kubectl exec sshpod -n seccomp-ssh-ns -- bash /pod-script.sh;
kubectl delete ns seccomp-ssh-ns
