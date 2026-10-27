# Network

All hosts live in `10.0.10.0/24`; the [gateway](gateway.md) routes it into the tailnet.

## Addresses

| Range | Use |
|---|---|
| `.1-25` | Management (router `.1`, `pve01` `.2`) |
| `.26-39` | Shared services (`gateway-01` `.26`) |
| `.40-59` | `k8s-prod`: `.40` API VIP, `.41-49` nodes, `.50-59` LoadBalancer IPs |
| `.60-79` | [Labs](labs.md); each lab sets its own IPs |
| `.80-199` | Free for tofu VMs |
| `.200-254` | DHCP |

Tofu VMs get a static address through cloud-init; `tofu/modules/vm` rejects an `ip` outside `.26-199`.

## Names

A VM is named `<role>-<nn>`: lowercase, with a two-digit number. Cluster nodes use the cluster name as the role (`k8s-prod-01`). Templates are named `<image>-<date>`. The VM name is also the hostname and the Tailscale node name.

VM IDs follow the address plan; see [Proxmox VM IDs](proxmox.md#vm-ids).
