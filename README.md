# infra

Infrastructure as code for my homelab.

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
