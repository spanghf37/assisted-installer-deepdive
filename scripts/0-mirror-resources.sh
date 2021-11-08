#!/bin/bash


RESOURCES_DIR=/opt/assisted-service-resources
TERRAVERSION=1.0.7
REGISTRY_USER=assisted-service
REGISTRY_PASSWORD=assisted-service
PULL_SECRET_REDHAT=/root/microshift/config.json
PULL_SECRET_UPDATE=/root/microshift/pull-secret-update.txt

## Clean
sudo rm -R $RESOURCES_DIR
sudo rm -R /opt/terraform
sudo podman container stop assisted-service-httpd && sudo podman container rm assisted-service-httpd
sudo podman container stop assisted-service-registry && sudo podman container rm assisted-service-registry


podman login quay.io --authfile $PULL_SECRET_REDHAT

## Create HTTPD server for assisted service AIR GAPPED resources

sudo dnf install -y podman
sudo firewall-cmd --add-port=8580/tcp --zone=public --permanent
sudo firewall-cmd --add-port=5015/tcp --zone=public --permanent
sudo firewall-cmd --reload
mkdir $RESOURCES_DIR
#sudo semanage fcontext -a -t httpd_sys_content_t "$RESOURCES_DIR/(/.*)?"
#sudo restorecon -Rv $RESOURCES_DIR
#ls -Z $RESOURCES_DIR

podman run -d --name assisted-service-httpd --restart=always \
-v $RESOURCES_DIR:/var/www/html:z \
-p 8580:8080/tcp \
registry.centos.org/centos/httpd-24-centos7:latest

(cd $RESOURCES_DIR && curl -L -O https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm)

(cd $RESOURCES_DIR && curl -L -O https://releases.hashicorp.com/terraform/${TERRAVERSION}/terraform_${TERRAVERSION}_linux_amd64.zip)

sudo dnf install -y git
git clone https://github.com/openshift/assisted-service $RESOURCES_DIR/assisted-service

host_fqdn=$( hostname --long )

sed -i 's/OPENSHIFT_VERSIONS=.*/OPENSHIFT_VERSIONS={"4.8":{"display_name":"4.8.13","release_version":"4.8.13","release_image":"'"$host_fqdn"':5015\/openshift-release-dev\/ocp-release:4.8.13-x86_64","rhcos_image":"http:\/\/'"$host_fqdn"':8580\/rhcos-4.8.14-x86_64-live.x86_64.iso","rhcos_rootfs":"http:\/\/'"$host_fqdn"':8580\/rhcos-live-rootfs.x86_64.img","rhcos_version":"48.84.202109241901-0","support_level":"production","default":true}}/' $RESOURCES_DIR/assisted-service/onprem-environment

sed -i 's/OS_IMAGES=.*/OS_IMAGES=[{"openshift_version":"4.8","cpu_architecture":"x86_64","url":"http:\/\/'"$host_fqdn"':8580\/rhcos-4.8.14-x86_64-live.x86_64.iso","rootfs_url":"http:\/\/'"$host_fqdn:8580"'\/rhcos-live-rootfs.x86_64.img","version":"48.84.202109241901-0"}]/' $RESOURCES_DIR/assisted-service/onprem-environment

sed -i 's/RELEASE_IMAGES=.*/RELEASE_IMAGES=[{"openshift_version":"4.8","cpu_architecture":"x86_64","url":"'"$host_fqdn"':5015\/openshift-release-dev\/ocp-release:4.8.13-x86_64","version":"4.8.13","default":true}]/' $RESOURCES_DIR/assisted-service/onprem-environment

( cd $RESOURCES_DIR && curl -L -O https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.8/4.8.14/rhcos-4.8.14-x86_64-live.x86_64.iso )
( cd $RESOURCES_DIR && curl -L -O https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.8/4.8.14/rhcos-live-rootfs.x86_64.img )


## Mirror containers for AIR GAP on local Docker registry
sudo yum -y install python3 httpd-tools jq
sudo mkdir -p $RESOURCES_DIR/registry/{auth,certs,data}

host_fqdn=$( hostname --long )
cert_c="FR"   # Country Name (C, 2 letter code)
cert_s="Var"          # Certificate State (S)
cert_l="Toulon"       # Certificate Locality (L)
cert_o="Marine Nationale"   # Certificate Organization (O)
cert_ou="CSD-M"      # Certificate Organizational Unit (OU)
cert_cn="${host_fqdn}"    # Certificate Common Name (CN)

openssl req \
    -newkey rsa:4096 \
    -nodes \
    -sha256 \
    -keyout $RESOURCES_DIR/registry/certs/domain.key \
    -x509 \
    -days 365 \
    -out $RESOURCES_DIR/registry/certs/domain.crt \
    -addext "subjectAltName = DNS:${host_fqdn}, DNS:quay.io" \
    -subj "/C=${cert_c}/ST=${cert_s}/L=${cert_l}/O=${cert_o}/OU=${cert_ou}/CN=${cert_cn}"

sudo cp $RESOURCES_DIR/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract

htpasswd -bBc $RESOURCES_DIR/registry/auth/htpasswd $REGISTRY_USER $REGISTRY_PASSWORD

podman create --name assisted-service-registry --restart=always -p 443:5000 -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry" -e "REGISTRY_HTTP_SECRET=ALongRandomSecretForRegistry" -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" -e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt" -e "REGISTRY_HTTP_TLS_KEY=/certs/domain.key" -e "REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true" -v $RESOURCES_DIR/registry/data:/var/lib/registry:z -v $RESOURCES_DIR/registry/auth:/auth:z -v $RESOURCES_DIR/registry/certs:/certs:z docker.io/library/registry:2

podman start assisted-service-registry

sudo dnf -y install skopeo

## Copy and update pull-secret.txt
host_fqdn=$( hostname --long )
b64auth=$( echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | openssl base64 )
AUTHSTRING="{\"$host_fqdn:5015\": {\"auth\": \"$b64auth\",\"email\": \"$USER@redhat.com\"}}"
jq ".auths += $AUTHSTRING"< $PULL_SECRET_REDHAT > $PULL_SECRET_UPDATE

podman login $host_fqdn:5015 --authfile $PULL_SECRET_UPDATE

skopeo login $host_fqdn:5015 --authfile $PULL_SECRET_UPDATE

skopeo copy docker://quay.io/openshift-release-dev/ocp-release:4.8.13-x86_64 docker://$host_fqdn:5015/openshift-release-dev/ocp-release:4.8.13-x86_64

