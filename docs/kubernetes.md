# Kubernetes

`k8s-prod` is a [Talos](https://www.talos.dev) cluster of three nodes on `pve01` (`tofu/stacks/k8s-prod`, built with `tofu/modules/talos-cluster`):

| Node | IP | VM ID |
|---|---|---|
| API VIP | `10.0.10.40` | |
| `k8s-prod-01` | `10.0.10.41` | `2041` |
| `k8s-prod-02` | `10.0.10.42` | `2042` |
| `k8s-prod-03` | `10.0.10.43` | `2043` |

Every node is a control plane that also runs workloads, with 4 cores, 12 GiB, a 64 GiB system disk and a 50 GiB disk for [Longhorn](https://longhorn.io), mounted at `/var/mnt/longhorn`. The Talos image adds the `iscsi-tools`, `nfs-utils`, `qemu-guest-agent` and `util-linux-tools` extensions (`talos/schematic.yaml`). [Cilium](https://cilium.io) is the CNI and replaces kube-proxy. CI applies the stack like any other and reaches the Talos (`50000`) and Kubernetes (`6443`) APIs over Tailscale (see [Network](network.md)).

```sh
task k8s:config        # write ~/.kube/k8s-prod and ~/.talos/k8s-prod from the state
export KUBECONFIG=~/.kube/k8s-prod TALOSCONFIG=~/.talos/k8s-prod
kubectl get nodes
talosctl health
```

## Flux

Tofu installs the [Flux Operator](https://fluxcd.control-plane.io/operator/) (no web UI) and a `FluxInstance` that syncs `clusters/k8s-prod` from `main` of [gitops](https://github.com/twanvanparidon/gitops) (`tofu/stacks/k8s-prod/flux.tf`). Everything else in the cluster comes from that repo.

`secrets/k8s-prod.sops.yaml` holds the keys tofu loads into `flux-system`:

| Key | Secret | Use |
|---|---|---|
| `flux_deploy_key`, `flux_known_hosts` | `flux-system` | Read-only deploy key `flux-k8s-prod` on the gitops repo |
| `flux_age_key` | `sops-age` | Decrypts `*.sops.yaml` in the gitops repo |

```sh
flux get kustomizations
```

To replace the deploy key, add a new key to the gitops repo with `gh repo deploy-key add`, put the private key in `flux_deploy_key`, and remove the old one after the apply.

## Upgrades

Applies run one resource at a time, so Talos changes reach the nodes one by one.

- **Kubernetes:** change `kubernetes_version` in `tofu/stacks/k8s-prod/main.tf`; the apply upgrades the nodes one by one.
- **Talos:** the stack pins its own `talos_version` and `schematic`, so a new image in `pve-prod` changes nothing here. Changing them upgrades the nodes to that installer image, one by one. Don't run `talosctl upgrade` by hand: the next apply would move the node back.
- **Config:** a machine config change applies to one node after the other; most changes need no reboot.
- **Hardware:** a change to `cores` or `memory` does not reboot the VMs; the apply warns that a reboot is pending. Reboot each node in turn and wait for it to be `Ready` before the next:

  ```sh
  kubectl drain k8s-prod-01 --ignore-daemonsets --delete-emptydir-data
  talosctl -n 10.0.10.41 reboot
  kubectl uncordon k8s-prod-01
  ```

- **Cilium:** change `cilium_version` or its values. Talos only creates missing objects from inline manifests, so after the apply run `talosctl upgrade-k8s --to <kubernetes_version>` to sync the changed ones, then restart Cilium: `kubectl -n kube-system rollout restart ds/cilium deploy/cilium-operator`.
- **Flux:** change the chart `version` or `distribution.version` in `flux.tf`.
