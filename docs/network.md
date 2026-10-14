# Network

All hosts live in `10.0.10.0/24`; the [gateway](gateway.md) routes it into the tailnet.

## Addresses

| Range | Use |
|---|---|
| `.1-25` | Management (router `.1`, `pve01` `.2`) |
| `.26-39` | Shared services (`gateway01` `.26`) |
| `.40-59` | `k8s-prod`: `.40` API VIP, `.41-49` nodes, `.50-59` LoadBalancer IPs |
| `.60-79` | CKA labs |
| `.80-199` | Free for tofu VMs |
| `.200-254` | DHCP |

Tofu VMs get a static address through cloud-init; `tofu/modules/vm` rejects an `ip` outside `.26-199`.

## VM IDs

| Range | Use |
|---|---|
| `1000-1999` | Templates; the ID comes from the image date |
| `2000-8999` | Tofu VMs |

A new VM's ID is 2000 plus the last octet of its IP: `.41` gets `2041`. `gateway01` keeps `2000`.
