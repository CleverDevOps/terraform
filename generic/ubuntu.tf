# instance the provider
provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "bionic" {
  name = "bionic"
  type = "dir"
  path = "/var/libvirt/guest_images/terraform-provider-libvirt-pool-ubuntu-bionic"
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "ubuntu-qcow2" {
  name   = "ubuntu-qcow2"
  pool   = libvirt_pool.bionic.name
  source = "https://cloud-images.ubuntu.com/releases/bionic/release/ubuntu-18.04-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "bionic_rootfs" {
  name           = "disk"
  base_volume_id = libvirt_volume.ubuntu-qcow2.id
  pool           = libvirt_pool.bionic.name
  size           = 107374182400
}


data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
}

data "template_file" "network_config" {
  template = file("${path.module}/network_config.cfg")
}

# for more info about paramater check this out
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
# Use CloudInit to add our ssh-key to the instance
# you can add also meta_data field
resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "commoninit.iso"
  user_data      = data.template_file.user_data.rendered
  network_config = data.template_file.network_config.rendered
  pool           = libvirt_pool.bionic.name
}

# Create the machine
resource "libvirt_domain" "domain-ubuntu-bionic" {
  name   = "ubuntu-terraform"
  memory = "16384"
  vcpu   = 8

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name = "br0"
    mac = "52:54:00:4e:e7:e0"
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
    volume_id = libvirt_volume.bionic_rootfs.id
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

# IPs: use wait_for_lease true or after creation use terraform refresh and terraform show for the ips of domain

