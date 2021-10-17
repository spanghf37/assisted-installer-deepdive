## Deploying the OpenShift Assisted Installer service on premise

#!/bin/bash

## Create SSHKEY for host
ssh-keygen -t ed25519

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
setenforce 0
dnf install -y @container-tools
dnf group install "Development Tools" -y
dnf -y install python3-pip socat make tmux git jq crun
cd /root
git clone https://github.com/openshift/assisted-service
cd assisted-service

## Change HOST IP
IP=10.0.0.1

AI_URL=http://$IP:8090

## Modify onprem-environment and Makefile to set proper URL and port forwarding
sed -i "s@SERVICE_BASE_URL=.*@SERVICE_BASE_URL=$AI_URL@" onprem-environment
sed -i "s/5432,8000,8090,8080/5432:5432 -p 8000:8000 -p 8090:8090 -p 8080:8080/" Makefile
make deploy-onprem
podman ps
podman pod ps
