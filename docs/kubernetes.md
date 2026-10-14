# Kubernetes

`k8s-prod` is a [Talos](https://www.talos.dev) cluster of three nodes on `pve01` (`tofu/stacks/k8s-prod`, built with `tofu/modules/talos-cluster`):

| Node | IP | VM ID |
|---|---|---|
| API VIP | `10.0.10.40` | |
| `k8s-prod-1` | `10.0.10.41` | `2041` |
| `k8s-prod-2` | `10.0.10.42` | `2042` |
| `k8s-prod-3` | `10.0.10.43` | `2043` |

Every node is a control plane that also runs workloads, with 4 cores, 12 GiB and 64 GiB of disk. [Cilium](https://cilium.io) is the CNI and replaces kube-proxy. CI applies the stack like any other and reaches the Talos (`50000`) and Kubernetes (`6443`) APIs over Tailscale (see [Network](network.md)).

```sh
task k8s:config        # write ~/.kube/k8s-prod and ~/.talos/k8s-prod from the state
export KUBECONFIG=~/.kube/k8s-prod TALOSCONFIG=~/.talos/k8s-prod
kubectl get nodes
talosctl health
```

## Upgrades

- **Kubernetes:** change `kubernetes_version` in `tofu/stacks/k8s-prod/main.tf`; the apply upgrades the nodes one by one.
- **Talos:** the stack pins its own `talos_version` and `schematic`, so a new image in `pve-prod` changes nothing here. Changing them upgrades every node to that installer image; for now all at once, without a drain (see #83). Don't run `talosctl upgrade` by hand: the next apply would move the node back.
- **Cilium:** change `cilium_version`; the new manifest applies on the next apply.
