#!/bin/bash

# rke2 versions and their release notes can be found here: https://github.com/rancher/rke2/releases
RKE_VERSION="v1.26.3+rke2r1"

# disable swap
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

# configure NetworkManager to ignore calico/flannel cni
# more info here: https://docs.rke2.io/known_issues#networkmanager
cat <<EOF > /etc/NetworkManager/conf.d/rke2-canal.conf
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:flannel*
EOF

# downloads the rke2 install script, if command executes successfully (exit code 0)
# continue with install by passing desired rke2 version and executing script
if curl -sfL https://get.rke2.io > /tmp/rke2-installer.sh; then
    INSTALL_RKE2_CHANNEL=${RKE_VERSION} /bin/sh /tmp/rke2-installer.sh
else
    echo "Failed to curl install script from https://get.rke2.io"
    exit 1
fi 

# Create config dir and file to disable rke2 from deploying the ingress controller addon
mkdir -p /etc/rancher/rke2/

cat <<EOF > /etc/rancher/rke2/config.yaml
disable:
  - rke2-ingress-nginx
EOF

# start the rke2-server service installed by the rke script above.
# Starting this service for the first time is what builds the k8 cluster
echo -e "\nStarting the rke2-server service, this may take a few minutes\n"
systemctl enable rke2-server
systemctl start rke2-server

# if helm isn't found locally, install latest version
if which helm &> /dev/null; then
    echo "Helm `$(which helm) version | awk '{print $1}' | cut -c 19-` is already installed, moving on"
else
    curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    bash /tmp/get_helm.sh
fi

# clean up
rm -f /tmp/rke2-installer.sh
rm -f /tmp/get_helm.sh

# checks if kubeconfig is already present before moving on
if [ -f "/root/.kube/config" ]; then
    echo -e "WARNING: kubeconfig at /root/.kube/config already detected \n"
    echo "WARNING:  Make sure to backup, delete, or rename config file"
    echo "========  then manually copy new kubeconfig with: cp /etc/rancher/rke2/rke2.yaml /root/.kube/config"
    exit 17
fi

# if directory exists but config is not present, copy new cluster kubeconfig
# else if directory is missing, create dir and copy new cluster kubeconfig
if [[ -d "/root/.kube" && -z "$(find /root/.kube -mindepth 1 -maxdepth 1 | grep config | read)" ]]; then
    cp /etc/rancher/rke2/rke2.yaml /root/.kube/config
elif [ ! -d "/root/.kube" ]; then
    mkdir /root/.kube
    cp /etc/rancher/rke2/rke2.yaml /root/.kube/config
fi

