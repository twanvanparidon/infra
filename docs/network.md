# Network

All hosts live in `10.0.10.0/24`; the [gateway](gateway.md) routes it into the tailnet.

## Addresses

| Range | Use |
|---|---|
| `.1-25` | Management (router `.1`, `pve01` `.2`) |
| `.26-125` | Tofu VMs, static through cloud-init (`gateway01` `.26`) |
| `.126-254` | DHCP |

`tofu/modules/vm` rejects an `ip` outside the tofu range.

## VM IDs

| Range | Use |
|---|---|
| `1000-1999` | Templates; the ID comes from the image date |
| `2000-8999` | Tofu VMs |
