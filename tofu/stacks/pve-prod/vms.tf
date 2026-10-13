# VMs on pve-prod, cloned from the newest debian-base template. A new template
# does not rebuild existing VMs; see tofu/modules/vm.
variable "ssh_keys" {
  description = "SSH public keys for the default user of every VM"
  type        = list(string)
}

locals {
  newest_template = proxmox_virtual_environment_vm.debian_base[local.debian_base_versions[0]].vm_id
}

# Checks the vm module and disk growth (#45).
module "test01" {
  source = "../../modules/vm"

  name        = "test01"
  node_name   = var.node_name
  vm_id       = 2000
  template_id = local.newest_template
  ip          = "10.0.10.26"
  disk_size   = 20
  ssh_keys    = var.ssh_keys
  tags        = ["test"]
}

output "vms" {
  description = "SSH destination by VM name"
  value = {
    (module.test01.name) = module.test01.ssh
  }
}
