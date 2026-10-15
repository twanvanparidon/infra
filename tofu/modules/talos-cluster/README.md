# talos-cluster

Create a [Talos](https://www.talos.dev) Kubernetes cluster on Proxmox. Every node is a control plane that also runs workloads; the Kubernetes API is on a VIP that one node holds at a time. [Cilium](https://cilium.io) is the CNI and replaces kube-proxy: it ships as an inline manifest in the machine config, so nodes come up `Ready` before anything else runs. Flux can take over the Helm release later. Cilium also hands out LoadBalancer IPs and announces them over ARP; the IP pools come from the GitOps repo. Kubelets request serving certificates from the cluster CA, which something in the cluster must approve (`kubelet-serving-cert-approver`); until then `kubectl logs` and `exec` fail.

```hcl
module "k8s_prod" {
  source = "../../modules/talos-cluster"

  name      = "k8s-prod"
  node_name = var.node_name
  vip       = "10.0.10.40"
  nodes = {
    k8s-prod-01 = { ip = "10.0.10.41", vm_id = 2041 }
    k8s-prod-02 = { ip = "10.0.10.42", vm_id = 2042 }
    k8s-prod-03 = { ip = "10.0.10.43", vm_id = 2043 }
  }

  image              = "local:import/talos-v1.14.2-3abf06e1d81e.qcow2"
  schematic          = "3abf06e1d81e509d779dc256f9feae6cd6d82c69337c661cbfc383a92594faf5"
  talos_version      = "v1.14.2"
  kubernetes_version = "v1.37.1"
  cilium_version     = "1.20.2"
}
```

Each VM imports its disk from the Talos nocloud image and gets its static IP from the Proxmox cloud-init drive. Tofu then applies the machine configs over the Talos API (`50000`) and bootstraps etcd on the first node by name, so the machine running tofu must reach the nodes.

Changing `kubernetes_version` upgrades Kubernetes in place. Changing `talos_version` or `schematic` upgrades every node to the matching installer image, all at once and without a drain. A new `image` does not rebuild running nodes.

The machine secrets, `kubeconfig` and `talosconfig` live in the state, so keep it encrypted.

## Inputs

| Name | Description | Default |
|---|---|---|
| `name` | Cluster name, also a Proxmox tag on every node | required |
| `node_name` | Proxmox node to run the VMs on | required |
| `nodes` | Nodes by hostname, each `{ ip, vm_id }`; an odd number | required |
| `vip` | Shared IPv4 address for the Kubernetes API | required |
| `image` | Volume ID of the Talos nocloud image | required |
| `schematic` | Image factory schematic ID of the image | required |
| `talos_version` | Talos version of the image | required |
| `kubernetes_version` | Kubernetes version; changing it upgrades the cluster | required |
| `cilium_version` | Cilium Helm chart version | required |
| `cores` | CPU cores per node | `4` |
| `memory` | Memory per node in MiB | `8192` |
| `disk_size` | Disk size per node in GiB | `40` |
| `gateway` | IPv4 gateway, also the DNS server | `10.0.10.1` |
| `tags` | Extra Proxmox tags; `tofu`, `talos` and the name are always added | `[]` |
| `pool_id` | Proxmox pool | `tofu` |
| `bridge` | Linux bridge for the network devices | `vmbr0` |
| `datastore_id` | Datastore for the disks and the cloud-init drives | `local-lvm` |

## Outputs

| Name | Description |
|---|---|
| `endpoint` | Kubernetes API URL, on the VIP |
| `nodes` | Node IPs by hostname |
| `kubeconfig` | Admin kubeconfig (sensitive) |
| `client_configuration` | Kubernetes API host and base64 client certificates, for the `kubernetes` and `helm` providers (sensitive) |
| `talosconfig` | `talosctl` config with every node as endpoint (sensitive) |
