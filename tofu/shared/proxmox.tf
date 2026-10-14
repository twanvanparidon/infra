# Shared by every Proxmox stack through a symlink. The API token comes from
# PROXMOX_VE_API_TOKEN: the plan-only dev token from sops locally, the CI token
# from the proxmox-apply environment on main. See .taskfiles/tofu.
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.116.0"
    }
    # Reads the checksums of images that Proxmox downloads.
    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
    }
    # Builds Talos image factory schematics, and Talos clusters.
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.12.0"
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
