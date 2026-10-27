# Gapped Zarf lab: a hub (Gitea from Zarf) and an edge on a VNet with no route
# out, sized like Raspberry Pis. The jump host sits on both networks without
# forwarding and is the only way in. See docs/labs.md.
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

variable "subnet" {
  description = "Subnet of the gapped VNet, a /24"
  type        = string
}

variable "octets" {
  description = "Last octet per VM, from the labs block; the jump host uses it in both networks"
  type = object({
    jump = number
    hub  = number
    edge = number
  })
}

variable "ssh_keys" {
  description = "SSH public keys for the default user"
  type        = list(string)
}

locals {
  vnet = "zarfgap"
  jump = {
    name   = "zarf-jump-01"
    ip     = "10.0.10.${var.octets.jump}"
    gapped = cidrhost(var.subnet, var.octets.jump)
  }
  gapped = {
    zarf-hub-01  = cidrhost(var.subnet, var.octets.hub)
    zarf-edge-01 = cidrhost(var.subnet, var.octets.edge)
  }
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

# A VNet in the `labs` simple zone, with no subnet: Proxmox gives the bridge no
# address, gateway or SNAT, so nothing on it reaches beyond it.
resource "proxmox_sdn_vnet" "gapped" {
  count = var.enabled ? 1 : 0

  id    = local.vnet
  zone  = "labs"
  alias = "Gapped Zarf lab"

  depends_on = [proxmox_sdn_applier.finalizer]
}

# Applies the VNet once it exists; the finalizer applies again after it is gone.
resource "proxmox_sdn_applier" "gapped" {
  count = var.enabled ? 1 : 0

  lifecycle {
    replace_triggered_by = [proxmox_sdn_vnet.gapped]
  }

  depends_on = [proxmox_sdn_vnet.gapped]
}

resource "proxmox_sdn_applier" "finalizer" {
  count = var.enabled ? 1 : 0
}

module "jump" {
  source = "../../modules/vm"
  count  = var.enabled ? 1 : 0

  name           = local.jump.name
  node_name      = var.node_name
  vm_id          = 2000 + var.octets.jump
  template_id    = local.newest_template
  ip             = local.jump.ip
  extra_networks = [{ bridge = local.vnet, ip = local.jump.gapped }]
  cores          = 1
  memory         = 1024
  disk_size      = 8
  ssh_keys       = var.ssh_keys
  tags           = ["lab", "zarf"]

  depends_on = [proxmox_sdn_applier.gapped]
}

module "gapped" {
  source   = "../../modules/vm"
  for_each = var.enabled ? local.gapped : {}

  name        = each.key
  node_name   = var.node_name
  vm_id       = 2000 + tonumber(split(".", each.value)[3])
  template_id = local.newest_template
  bridge      = local.vnet
  ip          = each.value
  # k3s needs a default route to pick its node IP. No host has this address,
  # so nothing still leaves the VNet. As the DNS server too, it keeps Proxmox
  # from giving the nodes its own nameserver and search domain.
  gateway   = cidrhost(var.subnet, 1)
  cores     = 4
  memory    = 4096
  disk_size = 32
  ssh_keys  = var.ssh_keys
  tags      = ["lab", "zarf"]

  depends_on = [proxmox_sdn_applier.gapped]
}

output "ssh_config" {
  description = "SSH config for ~/.ssh/config: the gapped nodes through the jump host; null when the lab is off"
  value = var.enabled ? join("\n", concat(
    ["Host ${local.jump.name}", "  HostName ${local.jump.ip}", "  User debian", ""],
    flatten([for name, ip in local.gapped : ["Host ${name}", "  HostName ${ip}", "  User debian", "  ProxyJump ${local.jump.name}", ""]]),
  )) : null
}
