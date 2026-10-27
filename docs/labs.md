# Labs

A lab is a throwaway environment in its own `tofu/stacks/lab-<name>` stack. CI plans and applies it like any other stack; a pull request switches it on or off.

## Start and stop

Set `enabled` in the stack's `terraform.tfvars` and merge:

```hcl
enabled = true   # false destroys the lab's VMs and networks
```

The stack and its state stay, so the next `true` brings the same lab back.

## Add a lab

- Create `tofu/stacks/lab-<name>` with symlinks to `../../shared/terraform.tf` and `../../shared/proxmox.tf`, like the other stacks.
- Declare `variable "enabled"` and create every resource only when it is `true`, for example `for_each = var.enabled ? local.nodes : {}`.
- Put IPs in `terraform.tfvars`, from the labs block in [Network](network.md); nothing is reserved per lab, so check that no other enabled lab uses them. The VM ID is 2000 plus the last octet, as usual.

## Gapped networks

A lab can have a network with no route out: a VNet in the `labs` SDN zone with no subnet, so Proxmox gives it no address, gateway or SNAT. Nodes on it reach only each other. A jump host with a NIC on both networks and no forwarding is the only way in; the lab prints an SSH config for it:

```sh
task tofu:output STACK=lab-zarf-gapped -- -raw ssh_config >> ~/.ssh/config
scp package.tar.zst zarf-hub-01:   # goes through the jump host, nothing stays on it
```
