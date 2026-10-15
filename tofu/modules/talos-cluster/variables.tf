variable "name" {
  description = "Cluster name, also a Proxmox tag on every node"
  type        = string
}

variable "node_name" {
  description = "Proxmox node to run the VMs on"
  type        = string
}

variable "nodes" {
  description = "Talos nodes by hostname, each with a static IPv4 address and a VM ID. The first by name bootstraps etcd."
  type = map(object({
    ip    = string
    vm_id = number
  }))

  validation {
    condition     = length(var.nodes) % 2 == 1
    error_message = "Give an odd number of nodes; every node runs etcd."
  }

  validation {
    condition     = alltrue([for n in values(var.nodes) : n.vm_id >= 2000 && n.vm_id <= 8999])
    error_message = "Each vm_id must be in 2000-8999; 1000-1999 are templates."
  }

  validation {
    condition     = alltrue([for n in values(var.nodes) : can(regex("^10\\.0\\.10\\.\\d{1,3}$", n.ip))])
    error_message = "Each ip must be in 10.0.10.0/24, without a prefix."
  }
}

variable "vip" {
  description = "Shared IPv4 address for the Kubernetes API, held by one node at a time"
  type        = string
}

variable "image" {
  description = "Volume ID of the Talos nocloud image to import, e.g. the talos_image output of pve-prod"
  type        = string
}

variable "schematic" {
  description = "Image factory schematic ID of the image, for the installer that upgrades use"
  type        = string
}

variable "talos_version" {
  description = "Talos version of the image, e.g. v1.14.2"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version, e.g. v1.37.1. Changing it upgrades the cluster."
  type        = string
}

variable "cilium_version" {
  description = "Cilium Helm chart version, e.g. 1.20.2"
  type        = string
}

variable "cores" {
  description = "CPU cores per node"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Memory per node in MiB"
  type        = number
  default     = 8192
}

variable "disk_size" {
  description = "Disk size per node in GiB"
  type        = number
  default     = 40
}

variable "longhorn_disk_size" {
  description = "Size in GiB of a second disk per node that Talos mounts at /var/mnt/longhorn; 0 for none"
  type        = number
  default     = 0
}

variable "gateway" {
  description = "IPv4 gateway, also the DNS server"
  type        = string
  default     = "10.0.10.1"
}

variable "tags" {
  description = "Extra Proxmox tags"
  type        = list(string)
  default     = []
}

variable "pool_id" {
  description = "Proxmox pool; the CI token can only write to `tofu`"
  type        = string
  default     = "tofu"
}

variable "bridge" {
  description = "Linux bridge for the network devices"
  type        = string
  default     = "vmbr0"
}

variable "datastore_id" {
  description = "Datastore for the disks and the cloud-init drives"
  type        = string
  default     = "local-lvm"
}
