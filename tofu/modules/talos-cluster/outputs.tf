output "endpoint" {
  description = "Kubernetes API URL, on the VIP"
  value       = local.endpoint
}

output "nodes" {
  description = "Node IPs by hostname"
  value       = { for name, node in var.nodes : name => node.ip }
}

output "kubeconfig" {
  description = "Admin kubeconfig"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "client_configuration" {
  description = "Kubernetes API host and base64 client certificates, for the kubernetes and helm providers"
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration
  sensitive   = true
}

output "talosconfig" {
  description = "talosctl config with every node as endpoint"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}
