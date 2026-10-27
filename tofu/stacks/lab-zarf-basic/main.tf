# Basic Zarf lab: one connected node, sized like a Raspberry Pi, to try
# `zarf init` and a package. See docs/labs.md.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

variable "enabled" {
  description = "Whether the lab exists"
  type        = bool
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "ip" {
  description = "IP of the node, in the labs block"
  type        = string
}

variable "ssh_keys" {
  description = "SSH public keys for the default user"
  type        = list(string)
}

# pve-prod creates the templates; their names sort by date.
data "proxmox_virtual_environment_vms" "debian_base" {
  node_name = var.node_name
  tags      = ["debian-base", "template"]
}

locals {
  newest_template = [
    for vm in reverse(sort([for vm in data.proxmox_virtual_environment_vms.debian_base.vms : "${vm.name}/${vm.vm_id}"])) :
    tonumber(split("/", vm)[1])
  ][0]
}

module "node" {
  source = "../../modules/vm"
  count  = var.enabled ? 1 : 0

  name        = "zarf-basic-01"
  node_name   = var.node_name
  vm_id       = 2000 + tonumber(split(".", var.ip)[3])
  template_id = local.newest_template
  ip          = var.ip
  cores       = 4
  memory      = 4096
  disk_size   = 32
  ssh_keys    = var.ssh_keys
  tags        = ["lab", "zarf"]
}

output "ssh" {
  description = "SSH destination, or null when the lab is off"
  value       = one(module.node[*].ssh)
}
