# A VM cloned from a debian-base template, with a static IP and a user from
# cloud-init. Clones are full, so a template can be deleted while its VMs run.
terraform {
  required_version = "~> 1.13"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.116.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.node_name
  vm_id     = var.vm_id
  pool_id   = var.pool_id
  tags      = sort(distinct(concat(["tofu"], var.tags)))

  clone {
    vm_id = var.template_id
    full  = true
  }

  # The image runs qemu-guest-agent; tofu reads the IP through it and shuts
  # the VM down cleanly.
  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory
  }

  # Same settings as the template disk, with a new size. growpart grows the
  # root filesystem on the next boot.
  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge = var.bridge
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = "${var.ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.gateway]
    }

    user_account {
      username = var.username
      keys     = var.ssh_keys
    }
  }

  lifecycle {
    # Changing the template must not rebuild a running VM by accident.
    ignore_changes = [clone]
  }
}
