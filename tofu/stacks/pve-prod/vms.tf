# VMs on pve-prod, cloned from the newest debian-base template. A new template
# does not rebuild existing VMs; see tofu/modules/vm.
variable "ssh_keys" {
  description = "SSH public keys for the default user of every VM"
  type        = list(string)
}

locals {
  newest_template = proxmox_virtual_environment_vm.debian_base[local.debian_base_versions[0]].vm_id
}

# Tailscale subnet router for 10.0.10.0/24 and SSH bastion into the server
# range. Ansible configures it: `task gateway:setup`. CI reaches the Proxmox
# API through it, so a broken gateway can only be fixed from the LAN.
module "gateway_01" {
  source = "../../modules/vm"

  name        = "gateway-01"
  node_name   = var.node_name
  vm_id       = 2000
  template_id = local.newest_template
  ip          = "10.0.10.26"
  cores       = 1
  memory      = 1024
  disk_size   = 8
  ssh_keys    = var.ssh_keys
  tags        = ["gateway"]
}

output "vms" {
  description = "SSH destination by VM name"
  value = {
    (module.gateway_01.name) = module.gateway_01.ssh
  }
}

moved {
  from = module.gateway01
  to   = module.gateway_01
}
