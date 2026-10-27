# vm

Clone a `debian-base` template into a VM with a static IP and a user from cloud-init. Clones are full, so a template can be deleted while its VMs run.

```hcl
module "web01" {
  source = "../../modules/vm"

  name        = "web01"
  node_name   = var.node_name
  vm_id       = 2001
  template_id = proxmox_virtual_environment_vm.debian_base["20261013"].vm_id
  ip          = "10.0.10.30"
  ssh_keys    = ["ssh-ed25519 AAAA... you@laptop"]
}
```

Then `ssh debian@10.0.10.30`.

A VM on a lab VNet with no way out sets `bridge`, an `ip` in that network and `gateway = null`. A VM on two networks keeps its first NIC on `vmbr0` and adds the other:

```hcl
  extra_networks = [{ bridge = "gapped", ip = "10.0.20.61" }]
```

Raise `disk_size` and reboot the VM to grow the root filesystem: tofu resizes the disk, and `growpart` grows the partition on boot. Changing `template_id` does not rebuild a VM; run `tofu apply -replace` for that.

## Inputs

| Name | Description | Default |
|---|---|---|
| `name` | VM name, also the hostname | required |
| `node_name` | Proxmox node to run the VM on | required |
| `vm_id` | VM ID, in 2000-8999 | required |
| `template_id` | ID of the `debian-base` template to clone | required |
| `ip` | Static IPv4 address of the first NIC, without a prefix; in 10.0.10.26-10.0.10.199 when on `10.0.10.0/24` | required |
| `ssh_keys` | SSH public keys for the user, at least one | required |
| `cores` | CPU cores | `2` |
| `memory` | Memory in MiB | `2048` |
| `disk_size` | Root disk size in GiB, at least 8 | `16` |
| `gateway` | IPv4 gateway of the first NIC, also the DNS server; `null` for a network with no way out | `10.0.10.1` |
| `extra_networks` | More NICs, each `{ bridge, ip }` in a /24, without a gateway | `[]` |
| `username` | User that cloud-init creates, with sudo | `debian` |
| `tags` | Proxmox tags; `tofu` is always added | `[]` |
| `pool_id` | Proxmox pool | `tofu` |
| `bridge` | Bridge or SDN VNet for the first NIC | `vmbr0` |
| `datastore_id` | Datastore for the root disk and the cloud-init drive | `local-lvm` |

## Outputs

| Name | Description |
|---|---|
| `vm_id` | VM ID |
| `name` | VM name |
| `ip` | Static IPv4 address |
| `ssh` | SSH destination, `user@ip` |
