output "vm_id" {
  description = "VM ID"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "name" {
  description = "VM name"
  value       = proxmox_virtual_environment_vm.this.name
}

output "ip" {
  description = "Static IPv4 address"
  value       = var.ip
}

output "ssh" {
  description = "SSH destination, user@ip"
  value       = "${var.username}@${var.ip}"
}
