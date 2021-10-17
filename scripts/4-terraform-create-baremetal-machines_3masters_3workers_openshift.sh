#!/bin/bash

## Start the nodes and the discovery process In this lab, BM nodes are virtual and need to be provisioned first. A Terraform file is provided and will build 3 Masters, 3 workers.
## All the VMS are using the previously generated ISO to boot

terraform -chdir=/opt/terraform/openshift-ha-ai-cluster init
terraform -chdir=/opt/terraform/openshift-ha-ai-cluster apply -auto-approve
