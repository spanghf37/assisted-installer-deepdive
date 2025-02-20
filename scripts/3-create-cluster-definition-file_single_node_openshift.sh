## Create a cluster definition file

## Single Node: "high_availability_mode": "None" and "schedulable_masters": true and "ingress_vip" parameter not set (absent)
## 3 nodes clusters: "high_availability_mode": "Full" and "schedulable_masters": true
## 3+ nodes clusters: "high_availability_mode": "Full" and "schedulable_masters": false
## You can choose if you want to handle loadbalancing in house or leave it to OCP by setting user_managed_networking to true. In both case, DHCP and DNS server are mandatory (Only DNS in the case of a static IP deployment)


## Attention : ne fonctionne que si $CLUSTER_ID ne contient que 1 unique cluster!

#!/bin/bash

## Change HOST AI IP
AI_URL='http://10.0.0.1:8090'

export CLUSTER_SSHKEY=$(cat ~/.ssh/id_ed25519.pub)
export PULL_SECRET=$(cat pull-secret.txt | jq -R .)

## Remove  "ingress_vip": "10.0.0.8",  parameter if Single Node Openshift

cat << EOF > ./3-deployment-openshift-sno.json.json
{
  "kind": "Cluster",
  "name": "openshift-sno",
  "openshift_version": "4.8",
  "ocp_release_image": "quay.io/openshift-release-dev/ocp-release:4.8.12-x86_64",
  "base_dns_domain": "colbert.def",
  "hyperthreading": "all",
  "schedulable_masters": true,
  "high_availability_mode": "None",
  "user_managed_networking": false,
  "platform": {
    "type": "baremetal"
   },
  "cluster_networks": [
    {
      "cidr": "10.128.0.0/14",
      "host_prefix": 23
    }
  ],
  "service_networks": [
    {
      "cidr": "172.31.0.0/16"
    }
  ],
  "machine_networks": [
    {
      "cidr": "10.0.0.0/16"
    }
  ],
  "network_type": "OVNKubernetes",
  "additional_ntp_source": "ntp1.hetzner.de",
  "vip_dhcp_allocation": false,
  "ssh_public_key": "$CLUSTER_SSHKEY",
  "pull_secret": $PULL_SECRET
}
EOF

## Use deployment-multinodes.json to register the new cluster
content=$(curl -s -X POST "$AI_URL/api/assisted-install/v1/clusters" \
   -d @./3-deployment-openshift-sno.json --header "Content-Type: application/json")
CLUSTER_ID=$( jq .id <<< "${content}" | sed 's/"//g')

## Check cluster is registered Once the cluster definition has been sent to an the API we should be able to retrieve its unique id
#CLUSTER_ID=$(curl -s -X GET "$AI_URL/api/assisted-install/v2/clusters?with_hosts=true" -H "accept: application/json" -H "get_unregistered_clusters: false"| jq -r '.[].id')
echo Check cluster is registered Once the cluster definition has been sent to an the API we should be able to retrieve its unique id
echo $CLUSTER_ID

## Check the new cluster status
echo Check the new cluster status
curl -s -X GET "$AI_URL/api/assisted-install/v2/clusters?with_hosts=true" -H "accept: application/json" -H "get_unregistered_clusters: false"| jq -r '.[].status'

## When registering a cluster, the assisted installer runs a series of validation tests to assess if the cluster is ready to be deployed. 'pending-for-input' tells us we need to take some actions. Let's take a look at validations_info:
echo Cluster validation tests
curl -s -X GET "$AI_URL/api/assisted-install/v2/clusters?with_hosts=true" -H "accept: application/json" -H "get_unregistered_clusters: false"| jq -r '.[].validations_info'|jq .

## Build the discovery boot ISO
## The discovery boot ISO is a live CoreOS image that the nodes will boot from. Once booted an introspection will be performed by the discovery agent and data sent to the assisted service. If the node passes the validation tests its status_info will be "Host is ready to be installed". We need some extra parameters to be injected into the ISO . To do so, we create a data file as described bellow:

cat << EOF > ./3-discovery-iso-params.json
{
  "ssh_public_key": "$CLUSTER_SSHKEY",
  "pull_secret": $PULL_SECRET,
  "image_type": "full-iso"
}
EOF

## ISO is now ready to be built! Let's make the API call! As you can see we use the data file so pull-secret and ssh public key are injected into the live ISO.
echo Building ISO
curl -s -X POST "$AI_URL/api/assisted-install/v1/clusters/$CLUSTER_ID/downloads/image" \
   -d @./3-discovery-iso-params.json \
   --header "Content-Type: application/json" | jq '.'

## Downloading ISO
echo Downloading ISO
curl \
  -L "$AI_URL/api/assisted-install/v1/clusters/$CLUSTER_ID/downloads/image" \
  -o /home/libvirt/images/discovery_image_openshift-sno.iso
