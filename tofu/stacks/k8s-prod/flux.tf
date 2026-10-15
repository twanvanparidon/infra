# Flux, run by the Flux Operator, syncs clusters/k8s-prod from the GitOps
# repo with a read-only deploy key. See docs/kubernetes.md.
locals {
  kubernetes = {
    host                   = module.cluster.client_configuration.host
    cluster_ca_certificate = base64decode(module.cluster.client_configuration.ca_certificate)
    client_certificate     = base64decode(module.cluster.client_configuration.client_certificate)
    client_key             = base64decode(module.cluster.client_configuration.client_key)
  }
}

provider "kubernetes" {
  host                   = local.kubernetes.host
  cluster_ca_certificate = local.kubernetes.cluster_ca_certificate
  client_certificate     = local.kubernetes.client_certificate
  client_key             = local.kubernetes.client_key
}

# Aliased: the module renders Cilium with the default helm provider, before
# the cluster exists.
provider "helm" {
  alias      = "cluster"
  kubernetes = local.kubernetes
}

data "sops_file" "secrets" {
  source_file = "${path.root}/../../../secrets/k8s-prod.sops.yaml"
}

resource "helm_release" "flux_operator" {
  provider = helm.cluster

  name             = "flux-operator"
  namespace        = "flux-system"
  create_namespace = true
  repository       = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart            = "flux-operator"
  version          = "0.61.0"

  values = [yamlencode({ web = { enabled = false } })]
}

resource "kubernetes_secret_v1" "deploy_key" {
  metadata {
    name      = "flux-system"
    namespace = "flux-system"
  }
  data = {
    identity    = data.sops_file.secrets.data["flux_deploy_key"]
    known_hosts = data.sops_file.secrets.data["flux_known_hosts"]
  }

  depends_on = [helm_release.flux_operator]
}

# Decrypts *.sops.yaml in the GitOps repo; Kustomizations refer to it.
resource "kubernetes_secret_v1" "sops_age" {
  metadata {
    name      = "sops-age"
    namespace = "flux-system"
  }
  data = {
    "age.agekey" = data.sops_file.secrets.data["flux_age_key"]
  }

  depends_on = [helm_release.flux_operator]
}

resource "helm_release" "flux_instance" {
  provider = helm.cluster

  name       = "flux"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"
  version    = "0.61.0"

  values = [yamlencode({
    instance = {
      distribution = { version = "2.9.x", registry = "ghcr.io/fluxcd" }
      sync = {
        kind       = "GitRepository"
        url        = "ssh://git@github.com/twanvanparidon/gitops.git"
        ref        = "refs/heads/main"
        path       = "clusters/k8s-prod"
        pullSecret = kubernetes_secret_v1.deploy_key.metadata[0].name
      }
    }
  })]

  depends_on = [kubernetes_secret_v1.sops_age]
}
