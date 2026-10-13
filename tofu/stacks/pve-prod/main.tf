# Base stack for the pve-prod node: the node and the tofu pool here, templates
# in templates.tf, VMs in vms.tf. VMs live in the tofu pool, the only place the
# CI token can write.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

data "proxmox_virtual_environment_node" "this" {
  node_name = var.node_name
}

data "proxmox_virtual_environment_pool" "tofu" {
  pool_id = "tofu"
}

output "node" {
  description = "Node name, CPU and memory"
  value = {
    name      = data.proxmox_virtual_environment_node.this.node_name
    cpu_count = data.proxmox_virtual_environment_node.this.cpu_count
    memory    = data.proxmox_virtual_environment_node.this.memory_total
  }
}

output "pool_members" {
  description = "VMs and containers in the tofu pool"
  value       = data.proxmox_virtual_environment_pool.tofu.members[*].vm_id
}
