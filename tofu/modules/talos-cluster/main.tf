# A Talos Kubernetes cluster on Proxmox. Every node is a control plane that
# also runs workloads, with Cilium as the CNI in place of kube-proxy.
terraform {
  required_version = "~> 1.13"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.116.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.12.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.3.0"
    }
  }
}

locals {
  ips       = [for name in sort(keys(var.nodes)) : var.nodes[name].ip]
  endpoint  = "https://${var.vip}:6443"
  installer = "factory.talos.dev/nocloud-installer/${var.schematic}:${var.talos_version}"
}

locals {
  # The second disk, as an XFS volume at /var/mnt/longhorn.
  longhorn_patches = var.longhorn_disk_size > 0 ? [yamlencode({
    apiVersion = "v1alpha1"
    kind       = "UserVolumeConfig"
    name       = "longhorn"
    provisioning = {
      diskSelector = { match = "disk.dev_path == \"/dev/sdb\"" }
      # Grows from minSize to fill the disk.
      minSize = "1GiB"
      grow    = true
    }
    filesystem = { type = "xfs" }
  })] : []
}

resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.nodes

  name        = each.key
  description = "Talos node of ${var.name}. Managed by OpenTofu."
  node_name   = var.node_name
  vm_id       = each.value.vm_id
  pool_id     = var.pool_id
  tags        = sort(distinct(concat(["tofu", "talos", var.name], var.tags)))

  operating_system {
    type = "l26"
  }

  # The image has the qemu-guest-agent extension.
  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.datastore_id
    import_from  = var.image
    interface    = "scsi0"
    size         = var.disk_size
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  dynamic "disk" {
    for_each = var.longhorn_disk_size > 0 ? [var.longhorn_disk_size] : []
    content {
      datastore_id = var.datastore_id
      interface    = "scsi1"
      size         = disk.value
      file_format  = "raw"
      iothread     = true
      discard      = "on"
      ssd          = true
    }
  }

  network_device {
    bridge = var.bridge
  }

  # The nocloud image reads its address from the cloud-init drive, so the node
  # is reachable at its own IP before it has a machine config.
  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.gateway]
    }
  }

  # A change to cores or memory waits for a manual reboot, one node at a
  # time; rebooting all at once loses etcd quorum.
  reboot_after_update = false

  lifecycle {
    # A new Talos image must not rebuild a running node; nodes upgrade with
    # `talosctl upgrade`.
    ignore_changes = [disk[0].import_from]
  }
}

data "helm_template" "cilium" {
  name         = "cilium"
  namespace    = "kube-system"
  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.kubernetes_version

  # The settings Talos needs: no kube-proxy, the API through KubePrism on each
  # node, and Talos's own cgroup mount.
  values = [yamlencode({
    ipam                 = { mode = "kubernetes" }
    kubeProxyReplacement = true
    k8sServiceHost       = "localhost"
    k8sServicePort       = 7445
    # LoadBalancer IPs, announced over ARP; the pools live in the GitOps repo.
    l2announcements    = { enabled = true }
    externalIPs        = { enabled = true }
    k8sClientRateLimit = { qps = 20, burst = 40 }
    # A Job makes the Hubble certificates in the cluster; Helm would render
    # new ones every plan and change the machine config each time.
    hubble = { tls = { auto = { method = "cronJob" } } }
    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }
    securityContext = {
      capabilities = {
        ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }
  })]
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "this" {
  for_each = var.nodes

  cluster_name       = var.name
  cluster_endpoint   = local.endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  # Talos 1.14 generates the config as separate documents; each patch
  # changes, replaces or deletes one of them.
  config_patches = concat([
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "UnattendedInstallConfig"
      installer  = { image = local.installer }
      provisioning = {
        diskSelector = { match = "disk.dev_path == \"/dev/sda\"" }
      }
    }),
    yamlencode({ apiVersion = "v1alpha1", kind = "HostnameConfig", "$patch" = "delete" }),
    yamlencode({ apiVersion = "v1alpha1", kind = "HostnameConfig", hostname = each.key }),
    # Without the control plane taint, every node runs workloads.
    yamlencode({ apiVersion = "v1alpha1", kind = "KubeNodeConfig", "$patch" = "delete" }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeNodeConfig"
      labels     = { "node-role.kubernetes.io/control-plane" = "" }
    }),
    # Serving certificates from the cluster CA, so metrics-server can verify
    # the kubelet. kubelet-serving-cert-approver approves them.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeletConfig"
      config     = { serverTLSBootstrap = true }
    }),
    yamlencode({ apiVersion = "v1alpha1", kind = "KubeFlannelCNIConfig", "$patch" = "delete" }),
    yamlencode({ apiVersion = "v1alpha1", kind = "KubeProxyConfig", enabled = false }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "LinkAliasConfig"
      name       = "lan"
      selector   = { match = "link.driver == \"virtio_net\"" }
    }),
    yamlencode({ apiVersion = "v1alpha1", kind = "Layer2VIPConfig", name = var.vip, link = "lan" }),
    # Sensitive only to keep thousands of manifest lines out of every plan.
    sensitive(yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeInlineManifestConfig"
      name       = "cilium"
      manifest   = data.helm_template.cilium.manifest
    })),
  ], local.longhorn_patches)
}

resource "talos_machine" "this" {
  for_each = var.nodes

  node                  = each.value.ip
  client_configuration  = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.this[each.key].machine_configuration
  # Without an image, provider 0.12 tries to upgrade a new node to "". The
  # image matches what the node runs, so nothing is upgraded.
  image            = local.installer
  drain_on_upgrade = false
  # talos_cluster owns Kubernetes upgrades.
  ignore_kubernetes_upgrade_drift = true

  depends_on = [proxmox_virtual_environment_vm.this]
}

resource "talos_cluster" "this" {
  node                 = local.ips[0]
  control_plane_nodes  = local.ips
  client_configuration = talos_machine_secrets.this.client_configuration
  kubernetes_version   = var.kubernetes_version

  depends_on = [talos_machine.this]
}

resource "talos_cluster_kubeconfig" "this" {
  node                 = local.ips[0]
  client_configuration = talos_machine_secrets.this.client_configuration

  depends_on = [talos_cluster.this]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.ips
  nodes                = local.ips
}
