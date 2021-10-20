## Deploying the OpenShift Assisted Installer service on premise

#!/bin/bash

RESOURCES_DIR=/opt/assisted-service-resources

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
setenforce 0
dnf install -y @container-tools
dnf group install "Development Tools" -y
dnf -y install python3-pip socat make tmux git jq crun
cd $RESOURCES_DIR/assisted-service

## Change HOST IP
IP="${host_fqdn}"

AI_URL=http://$IP:8090

## Modify onprem-environment and Makefile to set proper URL and port forwarding
sed -i "s@SERVICE_BASE_URL=.*@SERVICE_BASE_URL=$AI_URL@" onprem-environment
sed -i 's/PUBLIC_CONTAINER_REGISTRIES=.*/PUBLIC_CONTAINER_REGISTRIES='"$IP"':5015

sed -i "s/5432,8000,8090,8080/5432:5432 -p 8000:8000 -p 8090:8090 -p 8080:8080/" Makefile
make deploy-onprem
podman ps
podman pod ps
