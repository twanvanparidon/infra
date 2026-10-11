# Shared by every Proxmox stack through a symlink. The API token comes from
# PROXMOX_VE_API_TOKEN: the read-only dev token from sops locally, the CI token
# from the proxmox-apply environment on main. See .taskfiles/tofu.
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.116.0"
    }
  }
}

variable "proxmox_endpoint" {
  description = "Proxmox API URL, e.g. https://10.0.10.2:8006/"
  type        = string
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  # The node uses the self-signed certificate Proxmox generates.
  insecure = true
}
