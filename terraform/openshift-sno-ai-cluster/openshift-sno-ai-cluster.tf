terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}
provider "libvirt" {
  uri = "qemu:///system"
}
# resource "libvirt_network" "ocp_network" {
#   name = "ocp4-net"
#   mode = "nat"
#   autostart = true
#   domain = "lab.local"
#   addresses = ["192.167.124/24"]
#   bridge = "virbr-ocp4"
#   dhcp {
#         enabled = false
#         }
# }

variable "master" {
     type = list(string)
     default = ["openshift-sno"]
   }

####masters
resource "libvirt_volume" "fatdisk-masters" {
  # name           = "fatdisk-${element(var.master, count.index)}"
  name           = "fatdisk-${element(var.master, count.index)}"
  pool           = "images"
  size           = 130000000000
  count = "${length(var.master)}"
}


resource "libvirt_domain" "masters" {
  name   = "${element(var.master, count.index)}"
  memory = "10000"
  vcpu   = 1
  cpu  {
  mode = "host-passthrough"
  }
  running = true
  boot_device {
      dev = ["hd","cdrom"]
    }
  network_interface {
    network_name = "openshift-net"
    mac = "AA:BB:CC:11:41:1${count.index}"
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = "${element(libvirt_volume.fatdisk-masters.*.id, count.index)}"
  }
  disk {
      file = "/home/libvirt/images/discovery_image_openshift-sno.iso"
    }
  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
  count = "${length(var.master)}"
  # depends_on = [
  #   libvirt_network.ocp_network,
  # ]
}
