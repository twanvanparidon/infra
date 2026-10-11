# infra

Infrastructure as code for a Proxmox homelab: [OpenTofu](https://opentofu.org) with the [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox) provider for VMs and Kubernetes clusters, [Packer](https://www.packer.io) for golden images, and [Ansible](https://www.ansible.com) for configuring hosts.

Only CI applies changes.

## Requirements

- [devbox](https://www.jetify.com/devbox); it installs every other tool at a pinned version (tofu, tflint, packer, ansible, sops, age, task, ...). With [direnv](https://direnv.net) the tools load when you `cd` into the repo, otherwise run `devbox shell`.
- An age key at `~/.config/sops/age/keys.txt` that `.sops.yaml` encrypts for (see [Secrets](#secrets)).

## Quick start

```sh
devbox shell
task lint    # what CI runs: fmt, tflint, validate, ansible-lint, sops and gitleaks
task         # menu of every task
```

## Layout

| Path | Contents |
|---|---|
| `tofu/` | OpenTofu modules and stacks |
| `packer/` | Golden image templates |
| `ansible/` | Playbooks and roles |
| `secrets/` | SOPS encrypted files |
| `.taskfiles/` | Task includes: `sops` and the lint pipelines from [ci-runner](https://github.com/twanvanparidon/ci-runner) |
| `.github/workflows/` | CI, every step is a `task` in a ci-runner image |

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
