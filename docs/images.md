# Images

`packer/debian-base` builds the base image for VMs: the Debian 13 genericcloud image with `qemu-guest-agent`, `growpart`, unattended security upgrades and SSH hardening (keys only, no root login). It holds no users or keys; cloud-init sets those per VM.

```sh
task packer:build   # build with local QEMU into packer/debian-base/output-<date>/
task packer:test    # boot the newest build and check it
```

`packer:test` boots the image on a throwaway overlay with a test user from cloud-init, like a clone, and checks SSH, the guest agent, the hardening and disk growth. It leaves no VM or files behind.

The `packer` workflow builds and tests the image on every pull request that changes it. On `main`, and every Monday for Debian security updates, it also publishes the image as a `debian-base-<date>` GitHub release with a `SHA256SUMS` file, and deletes all but the newest 3. A second build on the same day gets `.1`, `.2`, so a release never changes. CI installs its tools with devbox, since no ci-runner image ships QEMU.

The build VM runs on the local machine, not on Proxmox: with KVM on Linux, with emulation on macOS (a few minutes on Apple silicon).

## Templates

`pve-prod` turns releases into templates (`tofu/stacks/pve-prod/templates.tf`): Proxmox downloads the qcow2 to `local`, checks it against `SHA256SUMS`, and imports it into a template in the `tofu` pool. Renovate adds each new release to the top of `debian_base_versions`; the first 3 get templates. A template's ID comes from its date (see [VM IDs](network.md#vm-ids)), so it never changes. VMs cloned from a dropped template keep running.

## Talos

`pve-prod` also downloads the Talos image for the Kubernetes clusters (`tofu/stacks/pve-prod/talos.tf`): the nocloud qcow2 from the [image factory](https://factory.talos.dev) for a schematic with the `qemu-guest-agent` extension, to `local`. Talos VMs import their disk from it; there is no template. Renovate bumps `talos_version`, which downloads the new image and removes the old one. Running nodes upgrade with `talosctl upgrade`, not from the image.
