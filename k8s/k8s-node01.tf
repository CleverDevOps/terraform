# instance the provider
# provider "libvirt" {
#   uri = "qemu:///system"
# }

resource "libvirt_pool" "bionic-k8s-node01" {
  name = "bionic-k8s-node01"
  type = "dir"
  path = "/var/libvirt/guest_images/terraform-provider-libvirt-pool-k8s-node01"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "ubuntu-qcow2-k8s-node01" {
  name   = "ubuntu-qcow2-k8s-node01"
  pool   = libvirt_pool.bionic-k8s-node01.name
  source = "https://cloud-images.ubuntu.com/releases/bionic/release/ubuntu-18.04-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "k8s-node01" {
  name           = "disk"
  base_volume_id = libvirt_volume.ubuntu-qcow2-k8s-node01.id
  pool           = libvirt_pool.bionic-k8s-node01.name
  size           = 107374182400
}


data "template_file" "user_data_k8s_node01" {
  template = file("${path.module}/cloud_init_k8s_node01.cfg")
}

data "template_file" "network_config_k8s_node01" {
  template = file("${path.module}/network_config.cfg")
}

# for more info about paramater check this out
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/node01/website/docs/r/cloudinit.html.markdown
# Use CloudInit to add our ssh-key to the instance
# you can add also meta_data field
resource "libvirt_cloudinit_disk" "cloudinit_k8s_node01" {
  name           = "cloudinit_k8s_node01.iso"
  user_data      = data.template_file.user_data_k8s_node01.rendered
  network_config = data.template_file.network_config_k8s_node01.rendered
  pool           = libvirt_pool.bionic-k8s-node01.name
}

# Create the machine
resource "libvirt_domain" "domain-k8s-node01" {
  name   = "k8s-node01"
  memory = "16384"
  vcpu   = 8

  cloudinit = libvirt_cloudinit_disk.cloudinit_k8s_node01.id

  network_interface {
    network_name = "br0"
    mac = "52:54:00:4e:a7:a1"
  }

  # IMPORTANT: this is a known bug on cloud images, since they expect a console
  # we need to pass it
  # https://bugs.launchpad.net/cloud-images/+bug/1573095
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
    volume_id = libvirt_volume.k8s-node01.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

terraform {
  required_version = ">= 0.12"
}