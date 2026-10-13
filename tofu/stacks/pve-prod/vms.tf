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
module "gateway01" {
  source = "../../modules/vm"

  name        = "gateway01"
  node_name   = var.node_name
  vm_id       = 2000
  template_id = local.newest_template
  ip          = "10.0.10.26"
  # test01 grew to 20 GiB (#45), and disks cannot shrink.
  disk_size = 20
  ssh_keys  = var.ssh_keys
  tags      = ["gateway"]
}

# gateway01 takes over test01's VM: same ID and IP, so a destroy and a create
# would race. On the next boot cloud-init sees a new instance and sets the
# new hostname and host keys.
moved {
  from = module.test01
  to   = module.gateway01
}

output "vms" {
  description = "SSH destination by VM name"
  value = {
    (module.gateway01.name) = module.gateway01.ssh
  }
}
