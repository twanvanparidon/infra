# Talos images from the image factory, for the Kubernetes clusters. Proxmox
# downloads the qcow2 to `local` as `import` content; Talos VMs import their
# disk from it.
locals {
  talos_version = "v1.14.2"
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/nfs-utils",
          "siderolabs/qemu-guest-agent",
        ]
      }
    }
  })
}

resource "proxmox_download_file" "talos" {
  node_name    = var.node_name
  datastore_id = "local"
  content_type = "import"
  # The URL ends in nocloud-amd64.qcow2 for every version and schematic.
  file_name = "talos-${local.talos_version}-${substr(talos_image_factory_schematic.this.id, 0, 12)}.qcow2"
  url       = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${local.talos_version}/nocloud-amd64.qcow2"
  # A factory image never changes; don't check the URL again on every plan.
  overwrite = false
}

output "talos_image" {
  description = "Volume ID of the Talos image, for import_from"
  value       = proxmox_download_file.talos.id
}
