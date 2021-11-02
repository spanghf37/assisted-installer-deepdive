## Deploying the OpenShift Assisted Installer service on premise

#!/bin/bash

RESOURCES_DIR=/opt/assisted-service-resources
PULL_SECRET_UPDATE=/home/pull-secret-update.txt

##Cleaning
podman pod stop assisted-installer
podman pod rm assisted-installer

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
setenforce 0
dnf install -y @container-tools
dnf group install "Development Tools" -y
dnf -y install python3-pip socat make tmux git jq crun
cd $RESOURCES_DIR/assisted-service

## Change HOST IP
host_fqdn=$( hostname --long)
IP="${host_fqdn}"

AI_URL=http://$IP:8090

## Update agent container image (/ocpmetal/assisted-installer-agent:latest) with local registry CRT (for oc adm release extract to work)
podman login $IP:5015 --authfile $PULL_SECRET_UPDATE
cat <<EOT > $RESOURCES_DIR/Dockerfile-assisted-installer-agent
FROM $IP:5015/ocpmetal/assisted-installer-agent:latest
ADD /registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/registry.crt
RUN chmod 644 /etc/pki/ca-trust/source/anchors/registry.crt && update-ca-trust extract
EOT
podman build --file $RESOURCES_DIR/Dockerfile-assisted-installer-agent --authfile $PULL_SECRET_UPDATE -t $IP:5015/ocpmetal/assisted-installer-agent:latest-custom-crt
podman push $IP:5015/ocpmetal/assisted-installer-agent:latest-custom-crt --authfile $PULL_SECRET_UPDATE

## Update assisted-service container image (/ocpmetal/assisted-service:latest) with local registry CRT (for oc adm release extract to work)
podman login $IP:5015 --authfile $PULL_SECRET_UPDATE
cat <<EOT > $RESOURCES_DIR/Dockerfile-assisted-service
FROM $IP:5015/ocpmetal/assisted-service:latest
ADD /registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/registry.crt
RUN chmod 644 /etc/pki/ca-trust/source/anchors/registry.crt && update-ca-trust extract
EOT
podman build --file $RESOURCES_DIR/Dockerfile-assisted-service --authfile $PULL_SECRET_UPDATE -t $IP:5015/ocpmetal/assisted-service:latest-custom-crt
podman push $IP:5015/ocpmetal/assisted-service:latest-custom-crt --authfile $PULL_SECRET_UPDATE


## Modify onprem-environment and Makefile to set proper URL and port forwarding
sed -i "s@SERVICE_BASE_URL=.*@SERVICE_BASE_URL=$AI_URL@" onprem-environment
sed -i 's/PUBLIC_CONTAINER_REGISTRIES=.*/PUBLIC_CONTAINER_REGISTRIES='"$IP"':5015/' onprem-environment
echo 'AGENT_DOCKER_IMAGE='"$IP"':5015/ocpmetal/assisted-installer-agent:latest-custom-crt' >> onprem-environment
echo "SKIP_CERT_VERIFICATION=true" >> onprem-environment
echo "SERVICE="$IP":5015/ocpmetal/assisted-service:latest-custom-crt" >> onprem-environment

sed -i "s/5432,8000,8090,8080/5432:5432 -p 8000:8000 -p 8090:8090 -p 8080:8080/" Makefile
make deploy-onprem
podman ps
podman pod ps
