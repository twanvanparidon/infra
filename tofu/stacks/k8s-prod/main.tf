# The prod Kubernetes cluster: three Talos nodes on pve01. See
# tofu/modules/talos-cluster and docs/kubernetes.md.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

locals {
  # Pinned here, not taken from pve-prod: the cluster keeps the Talos version
  # it was created with until it is upgraded on purpose. pve-prod must still
  # hold this image for new nodes.
  talos_version = "v1.14.2"
  schematic     = "c23d16533980fd972f96a79cc22130404615c16de18f43da4a40d801d4fe8d6a"
}

module "cluster" {
  source = "../../modules/talos-cluster"

  name      = "k8s-prod"
  node_name = var.node_name
  vip       = "10.0.10.40"
  nodes = {
    k8s-prod-01 = { ip = "10.0.10.41", vm_id = 2041 }
    k8s-prod-02 = { ip = "10.0.10.42", vm_id = 2042 }
    k8s-prod-03 = { ip = "10.0.10.43", vm_id = 2043 }
  }

  image              = "local:import/talos-${local.talos_version}-${substr(local.schematic, 0, 12)}.qcow2"
  schematic          = local.schematic
  talos_version      = local.talos_version
  kubernetes_version = "v1.37.1"
  cilium_version     = "1.20.2"

  cores     = 4
  memory    = 12288
  disk_size = 64

  longhorn_disk_size = 50
}

moved {
  from = module.cluster.proxmox_virtual_environment_vm.this["k8s-prod-1"]
  to   = module.cluster.proxmox_virtual_environment_vm.this["k8s-prod-01"]
}

moved {
  from = module.cluster.proxmox_virtual_environment_vm.this["k8s-prod-2"]
  to   = module.cluster.proxmox_virtual_environment_vm.this["k8s-prod-02"]
}

moved {
  from = module.cluster.proxmox_virtual_environment_vm.this["k8s-prod-3"]
  to   = module.cluster.proxmox_virtual_environment_vm.this["k8s-prod-03"]
}

moved {
  from = module.cluster.talos_machine.this["k8s-prod-1"]
  to   = module.cluster.talos_machine.this["k8s-prod-01"]
}

moved {
  from = module.cluster.talos_machine.this["k8s-prod-2"]
  to   = module.cluster.talos_machine.this["k8s-prod-02"]
}

moved {
  from = module.cluster.talos_machine.this["k8s-prod-3"]
  to   = module.cluster.talos_machine.this["k8s-prod-03"]
}

output "endpoint" {
  description = "Kubernetes API URL"
  value       = module.cluster.endpoint
}

output "nodes" {
  description = "Node IPs by hostname"
  value       = module.cluster.nodes
}

output "kubeconfig" {
  description = "Admin kubeconfig; `task k8s:config` writes it to ~/.kube"
  value       = module.cluster.kubeconfig
  sensitive   = true
}

output "talosconfig" {
  description = "talosctl config; `task k8s:config` writes it to ~/.talos"
  value       = module.cluster.talosconfig
  sensitive   = true
}
