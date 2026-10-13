variable "name" {
  description = "VM name, also the hostname"
  type        = string
}

variable "node_name" {
  description = "Proxmox node to run the VM on"
  type        = string
}

variable "vm_id" {
  description = "VM ID, in 2000-8999"
  type        = number

  validation {
    condition     = var.vm_id >= 2000 && var.vm_id <= 8999
    error_message = "vm_id must be in 2000-8999; 1000-1999 are templates."
  }
}

variable "template_id" {
  description = "ID of the debian-base template to clone. Changing it later does not rebuild the VM; use `tofu apply -replace`."
  type        = number
}

variable "cores" {
  description = "CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MiB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Root disk size in GiB; at least the template's 8. Raising it grows the filesystem on the next boot."
  type        = number
  default     = 16

  validation {
    condition     = var.disk_size >= 8
    error_message = "disk_size must be at least 8 GiB, the template's disk size."
  }
}

variable "ip" {
  description = "Static IPv4 address in 10.0.10.26-10.0.10.125, without a prefix"
  type        = string

  validation {
    condition = (
      can(regex("^10\\.0\\.10\\.\\d{1,3}$", var.ip)) &&
      try(tonumber(split(".", var.ip)[3]) >= 26 && tonumber(split(".", var.ip)[3]) <= 125, false)
    )
    error_message = "ip must be in 10.0.10.26-10.0.10.125, the range for tofu VMs."
  }
}

variable "gateway" {
  description = "IPv4 gateway, also the DNS server"
  type        = string
  default     = "10.0.10.1"
}

variable "username" {
  description = "User that cloud-init creates, with sudo"
  type        = string
  default     = "debian"
}

variable "ssh_keys" {
  description = "SSH public keys for the user"
  type        = list(string)

  validation {
    condition     = length(var.ssh_keys) > 0
    error_message = "Give at least one SSH key; the image has no passwords."
  }
}

variable "tags" {
  description = "Proxmox tags"
  type        = list(string)
  default     = []
}

variable "pool_id" {
  description = "Proxmox pool; the CI token can only write to `tofu`"
  type        = string
  default     = "tofu"
}

variable "bridge" {
  description = "Linux bridge for the network device"
  type        = string
  default     = "vmbr0"
}

variable "datastore_id" {
  description = "Datastore for the root disk and the cloud-init drive"
  type        = string
  default     = "local-lvm"
}
