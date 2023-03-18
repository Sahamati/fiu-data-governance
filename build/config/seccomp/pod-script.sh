#! /bin/bash

cp /etc/ssh-key/ssh-key /root/ssh-key
chmod 0400 /root/ssh-key
mkdir -p /root/.ssh

for ip in $NODE_IPs; do
	echo "Uploading file to Node ${ip}"
	ssh-keyscan ${ip} >> "/root/.ssh/known_hosts" 2>/dev/null
	scp -i /root/ssh-key /${SECCOMP_FILE} ${AZURE_USER}@${ip}: 2>/dev/null 
	ssh -i /root/ssh-key ${AZURE_USER}@${ip} "sudo mkdir -p /var/lib/kubelet/seccomp/; sudo cp ${SECCOMP_FILE} /var/lib/kubelet/seccomp/" 2>/dev/null
done
