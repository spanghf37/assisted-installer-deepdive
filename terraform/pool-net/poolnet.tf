terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}
# instance the provider
provider "libvirt" {
   uri = "qemu:///system"
}
resource "libvirt_pool" "images" {
  name = "images"
  type = "dir"
  path = "/home/libvirt/images"
}
#resource "libvirt_network" "ocp_network" {
#  name = "openshift-net"
#  mode = "nat"
#  autostart = true
#  domain = "colbert.def"
#  addresses = ["10.0.40.0/16"]
#  bridge = "virbr-openshift"
#  dhcp {
#        enabled = false
#        }
#}
