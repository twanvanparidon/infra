# Talos images from the image factory, for the Kubernetes clusters. Proxmox
# downloads the qcow2 to `local` as `import` content; Talos VMs import their
# disk from it.
locals {
  talos_version = "v1.14.2"
  # ID of talos/schematic.yaml. CI cannot reach the factory, so after changing
  # the file, run `task talos:schematic` and paste the ID here.
  talos_schematic = "3abf06e1d81e509d779dc256f9feae6cd6d82c69337c661cbfc383a92594faf5"
}

resource "proxmox_download_file" "talos" {
  node_name    = var.node_name
  datastore_id = "local"
  content_type = "import"
  # The URL ends in nocloud-amd64.qcow2 for every version and schematic.
  file_name = "talos-${local.talos_version}-${substr(local.talos_schematic, 0, 12)}.qcow2"
  url       = "https://factory.talos.dev/image/${local.talos_schematic}/${local.talos_version}/nocloud-amd64.qcow2"
  # A factory image never changes; don't check the URL again on every plan.
  overwrite = false
}

output "talos_image" {
  description = "Volume ID of the Talos image, for import_from"
  value       = proxmox_download_file.talos.id
}
