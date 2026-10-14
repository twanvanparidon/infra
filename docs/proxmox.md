# Proxmox access

OpenTofu talks to Proxmox with two API tokens, both privilege separated:

| Token | Rights | Where |
|---|---|---|
| `tofu-dev@pve!dev` | `PVEAuditor` on `/`, `VM.Config.Disk` on the `tofu` pool (`TofuPlan`) | `secrets/proxmox.sops.yaml` |
| `tofu-ci@pve!ci` | VMs in the `tofu` pool, `local-lvm`, the node's bridges; downloads images to `local` (`TofuImages`, `TofuDownload`) | The `proxmox-apply` environment secret, nowhere else |

`task pve:access` creates the pool, roles, users, tokens and ACLs and enables `import` content on `local`, with Ansible over SSH as `root`; run `ssh-copy-id root@10.0.10.2` once first. Re-running changes nothing. A token's secret is shown only when it is created: the dev token goes into sops, the CI token is printed once. To rotate one, remove it with `pveum user token remove <user> <token>` on the host and run the task again.

VMs that are not in the `tofu` pool are out of reach for CI. `TofuDownload` grants `Sys.AccessNetwork` on the node, because Proxmox's `download-url` API requires it. `TofuPlan` lets plans read the disks of VMs in the pool: Proxmox shows a VM's disk volume only with `VM.Config.Disk`, which also allows changing that VM's disks.

## CI over Tailscale

CI runs on GitHub-hosted runners and reaches the Proxmox API over [Tailscale](https://tailscale.com) through the [gateway](gateway.md): `task tailscale:up` joins the tailnet as an ephemeral `tag:ci` node and routes `10.0.10.0/24` through `tailscale0`. Jobs that use it run their container as root with `--cap-add=NET_ADMIN --device=/dev/net/tun`; userspace mode does not work, because its proxy dials subnet routes outside the tunnel. The tailnet policy allows `tag:ci` only the Proxmox API (`10.0.10.2:8006`) and the Talos (`50000`) and Kubernetes (`6443`) APIs of the `k8s-prod` block (see [Network](network.md)); `tailscale/policy.hujson` holds a copy of the policy. The `tailnet` workflow checks the connection.

| Environment | Branches | Secrets |
|---|---|---|
| `proxmox-plan` | any | `TS_OAUTH_SECRET` |
| `proxmox-apply` | `main` | `TS_OAUTH_SECRET`, `PROXMOX_VE_API_TOKEN` |

Workflow logs are public. Never print Tailscale status, `netcheck` or verbose output, or any other network details in a workflow: they can reveal the home IP. `task tailscale:up` sends all Tailscale output to `/dev/null` for this reason.
