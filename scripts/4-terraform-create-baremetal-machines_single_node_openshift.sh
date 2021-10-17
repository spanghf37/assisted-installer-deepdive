#!/bin/bash

## Start the nodes and the discovery process In this lab, BM nodes are virtual and need to be provisioned first. A Terraform file is provided and will build 1 Single Node Openshift.
## All the VMS are using the previously generated ISO to boot

terraform -chdir=/opt/terraform/openshift-sno-ai-cluster init
terraform -chdir=/opt/terraform/openshift-sno-ai-cluster apply -auto-approve
