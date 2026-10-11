# infra

Infrastructure as code for a Proxmox homelab: [OpenTofu](https://opentofu.org) with the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox) provider for VMs and Kubernetes clusters, [Packer](https://www.packer.io) for golden images, and [Ansible](https://www.ansible.com) for configuring hosts.

Only CI applies changes.

## Requirements

- [devbox](https://www.jetify.com/devbox); it installs every other tool at a pinned version (tofu, tflint, packer, ansible, sops, age, task, ...). With [direnv](https://direnv.net) the tools load when you `cd` into the repo, otherwise run `devbox shell`.
- An age key at `~/.config/sops/age/keys.txt` that `.sops.yaml` encrypts for (see [Secrets](#secrets)).

## Quick start

```sh
devbox shell
task lint    # what CI runs: fmt, tflint, validate, ansible-lint, zizmor, sops and gitleaks
task         # menu of every task
task tofu:plan STACK=test   # plan one stack under tofu/stacks
```

## State

Each stack under `tofu/stacks/` keeps its state in `terraform.tfstate` next to the code, committed to the repo. OpenTofu encrypts state and plan files with a passphrase from `secrets/tofu.sops.yaml`; the `tofu` tasks pass it in through `TF_ENCRYPTION`, and without it `tofu plan` fails.

A pull request that changes a stack gets a `tofu plan` comment for it, updated on every push. After the merge, CI applies the stack and commits its state to `main`; one apply per stack runs at a time.

A stack with a `.ci-skip` file (its content says why) is left out of CI plan, apply and drift.

The daily `drift` workflow, also started by hand from the Actions tab, plans every stack and fails when the infrastructure no longer matches the code.

## Layout

| Path | Contents |
|---|---|
| `tofu/` | OpenTofu stacks, modules, and `shared/` config symlinked into every stack |
| `packer/` | Golden image templates |
| `ansible/` | Playbooks and roles |
| `secrets/` | SOPS encrypted files |
| `.taskfiles/` | Task includes: `sops`, `tofu` (init and plan a stack) and the lint pipelines from [ci-runner](https://github.com/twanvanparidon/ci-runner) |
| `.github/workflows/` | CI, every step is a `task` in a ci-runner image |

## Proxmox access

OpenTofu talks to Proxmox with two API tokens, both privilege separated:

| Token | Rights | Where |
|---|---|---|
| `tofu-dev@pve!dev` | `PVEAuditor` on `/` (read-only) | `secrets/proxmox.sops.yaml` |
| `tofu-ci@pve!ci` | VMs in the `tofu` pool, `local-lvm`, the node's bridges | The `proxmox-apply` environment secret, nowhere else |

`task pve:access` creates the pool, users, tokens and ACLs with Ansible over SSH as `root`; run `ssh-copy-id root@10.0.10.2` once first. Re-running changes nothing. A token's secret is shown only when it is created: the dev token goes into sops, the CI token is printed once. To rotate one, remove it with `pveum user token remove <user> <token>` on the host and run the task again.

VMs that are not in the `tofu` pool are out of reach for CI.

CI runs on GitHub-hosted runners and reaches the Proxmox API over [Tailscale](https://tailscale.com): `task tailscale:up` joins the tailnet as an ephemeral `tag:ci` node, without root, and serves an HTTP proxy on `localhost:1055`. The tailnet policy allows `tag:ci` only `10.0.10.2:8006`; `tailscale/policy.hujson` holds that part of the policy. The `tailnet` workflow checks the connection.

| Environment | Branches | Secrets |
|---|---|---|
| `proxmox-plan` | any | `TS_OAUTH_SECRET` |
| `proxmox-apply` | `main` | `TS_OAUTH_SECRET`, `PROXMOX_VE_API_TOKEN` |

Workflow logs are public. Never print Tailscale status, `netcheck` or verbose output, or any other network details in a workflow: they can reveal the home IP. `task tailscale:up` sends all Tailscale output to `/dev/null` for this reason.

## Secrets

Secrets are files named `*.sops.<ext>`, encrypted with [SOPS](https://getsops.io) and [age](https://age-encryption.org) for two keys (see `.sops.yaml`):

| Key | Where |
|---|---|
| Personal | `~/.config/sops/age/keys.txt` |
| CI | The `SOPS_AGE_KEY` repo secret |

```sh
task sops:encrypt FILE=secrets/<name>.sops.yaml   # encrypt a new file in place
sops edit secrets/<name>.sops.yaml                # change it later
task sops:check                                   # decrypt every file with your key
task sops:ci-key                                  # replace the CI key
```

`task leaks` scans the tree and the git history for plaintext secrets.

## License

[MIT](LICENSE)
