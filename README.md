# infra

Infrastructure as code for a Proxmox homelab: [OpenTofu](https://opentofu.org) with the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox) provider for VMs and Kubernetes clusters, [Packer](https://www.packer.io) for golden images, and [Ansible](https://www.ansible.com) for configuring hosts.

Only CI applies changes.

## Requirements

- [devbox](https://www.jetify.com/devbox); it installs every other tool at a pinned version (tofu, tflint, packer, ansible, sops, age, task, ...). With [direnv](https://direnv.net) the tools load when you `cd` into the repo, otherwise run `devbox shell`.
- An age key at `~/.config/sops/age/keys.txt` that `.sops.yaml` encrypts for (see [Secrets](docs/secrets.md)).

## Quick start

```sh
devbox shell
task lint    # what CI runs: fmt, tflint, validate, ansible-lint, zizmor, sops and gitleaks
task         # menu of every task
task tofu:plan STACK=test   # plan one stack under tofu/stacks
```

## Layout

| Path | Contents |
|---|---|
| `tofu/` | OpenTofu stacks, modules, and `shared/` config symlinked into every stack |
| `packer/` | Golden image templates |
| `ansible/` | Playbooks and roles |
| `secrets/` | SOPS encrypted files |
| `tailscale/` | A copy of the tailnet policy |
| `docs/` | The docs below |
| `.taskfiles/` | Task includes: `sops`, `tofu` (init and plan a stack) and the lint pipelines from [ci-runner](https://github.com/twanvanparidon/ci-runner) |
| `.github/workflows/` | CI, every step is a `task` in a ci-runner image |

## Docs

| Page | Contents |
|---|---|
| [State](docs/state.md) | Encrypted state, plans on pull requests, applies on `main`, drift |
| [Images](docs/images.md) | The `debian-base` image and its Proxmox templates |
| [Proxmox access](docs/proxmox.md) | API tokens, roles, and how CI reaches Proxmox over Tailscale |
| [Gateway](docs/gateway.md) | `gateway-01`: subnet router and SSH bastion |
| [Network](docs/network.md) | Address plan and VM IDs |
| [Kubernetes](docs/kubernetes.md) | The `k8s-prod` Talos cluster, its configs and upgrades |
| [Secrets](docs/secrets.md) | SOPS, age keys and leak scans |

## License

[MIT](LICENSE)
