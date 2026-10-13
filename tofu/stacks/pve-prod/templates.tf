# VM templates from the debian-base releases that CI publishes (see packer/).
# Proxmox downloads each qcow2 to `local` as `import` content, checks it against
# the release's SHA256SUMS, and imports it into a template on `local-lvm`.
locals {
  # Newest first. Renovate puts each new release at the top; only the first 3
  # get templates, so the next one drops the oldest. VMs cloned from a dropped
  # template keep running. Trim the tail by hand whenever.
  debian_base_versions = [
    "20261013",
  ]

  debian_base = {
    for version in slice(local.debian_base_versions, 0, min(3, length(local.debian_base_versions))) :
    version => {
      date    = split(".", version)[0]
      rebuild = length(split(".", version)) > 1 ? tonumber(split(".", version)[1]) : 0
    }
  }

  release_url = "https://github.com/twanvanparidon/infra/releases/download"
}

data "http" "debian_base_sums" {
  for_each = local.debian_base

  url = "${local.release_url}/debian-base-${each.key}/SHA256SUMS"
}

resource "proxmox_download_file" "debian_base" {
  for_each = local.debian_base

  node_name    = var.node_name
  datastore_id = "local"
  content_type = "import"
  url          = "${local.release_url}/debian-base-${each.key}/debian-base-${each.key}.qcow2"
  # Releases are pruned after a while; the checksum only matters for the
  # download, so a missing SHA256SUMS later on changes nothing.
  checksum           = data.http.debian_base_sums[each.key].status_code == 200 ? split(" ", data.http.debian_base_sums[each.key].response_body)[0] : null
  checksum_algorithm = "sha256"
  # A release never changes; don't check the URL again on every plan.
  overwrite = false

  lifecycle {
    ignore_changes = [checksum]
  }
}

resource "proxmox_virtual_environment_vm" "debian_base" {
  for_each = local.debian_base

  name        = "debian-base-${replace(each.key, ".", "-")}"
  description = "debian-base ${each.key} template. Managed by OpenTofu."
  tags        = ["debian-base", "template"]
  node_name   = var.node_name
  pool_id     = data.proxmox_virtual_environment_pool.tofu.pool_id
  # Stable per release, in 1000-1999: 1000 + 2 * (day of year, 31-day months)
  # + rebuild, so a same-day rebuild (.1) gets the next ID.
  vm_id    = 1000 + ((tonumber(substr(each.value.date, 4, 2)) - 1) * 31 + tonumber(substr(each.value.date, 6, 2)) - 1) * 2 + each.value.rebuild
  template = true
  started  = false

  operating_system {
    type = "l26"
  }

  # The image has qemu-guest-agent installed.
  agent {
    enabled = true
  }

  cpu {
    cores = 1
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 1024
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.debian_base[each.key].id
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge = "vmbr0"
  }

  # genericcloud images log to the serial console.
  serial_device {}

  vga {
    type = "serial0"
  }

  lifecycle {
    precondition {
      condition     = each.value.rebuild <= 1
      error_message = "Only one same-day rebuild of debian-base fits the template ID scheme."
    }
  }
}

output "templates" {
  description = "debian-base template IDs by version"
  value       = { for version, vm in proxmox_virtual_environment_vm.debian_base : version => vm.vm_id }
}
