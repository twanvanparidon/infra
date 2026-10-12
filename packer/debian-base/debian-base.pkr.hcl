# Debian 13 base image: the official genericcloud image with the guest agent,
# unattended upgrades and SSH hardening. The build VM runs on the local machine
# with QEMU; cloud-init creates a temporary `packer` user that the last step
# removes. No users or keys stay in the image: the `vm` module sets them per VM.
# Build: `task packer:build`.
packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "1.1.7"
    }
  }
}

variable "accelerator" {
  description = "QEMU accelerator: kvm on Linux, tcg (emulation, slow) elsewhere"
  type        = string
  default     = "kvm"
}

variable "image_url" {
  description = "Debian genericcloud qcow2 to start from"
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "image_checksum" {
  description = "Checksum of image_url, or a checksum file"
  type        = string
  default     = "file:https://cloud.debian.org/images/cloud/trixie/latest/SHA512SUMS"
}

locals {
  version = formatdate("YYYYMMDD", timestamp())
  # Only for the build VM, which listens on localhost; the last step removes the user.
  password = uuidv4()
}

source "qemu" "debian-base" {
  iso_url          = var.image_url
  iso_checksum     = var.image_checksum
  disk_image       = true
  skip_resize_disk = true
  format           = "qcow2"
  disk_compression = true
  # Lets fstrim in cleanup.sh shrink the image.
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"

  accelerator = var.accelerator
  cpus        = 2
  memory      = 2048
  headless    = true

  # NoCloud seed for the build VM.
  cd_label = "cidata"
  cd_content = {
    "meta-data" = "instance-id: packer-debian-base\n"
    "user-data" = templatefile("user-data.pkrtpl.yaml", { password = local.password })
  }

  ssh_username = "packer"
  ssh_password = local.password
  # Emulation on macOS takes minutes to boot.
  ssh_timeout = "30m"

  # Remove the build user last; --force because its own session is still open.
  shutdown_command = "sudo sh -c 'userdel --force --remove packer; rm -f /etc/sudoers.d/90-cloud-init-users; shutdown -P now'"

  output_directory = "${path.root}/output-${local.version}"
  vm_name          = "debian-base-${local.version}.qcow2"
}

build {
  sources = ["source.qemu.debian-base"]

  provisioner "shell" {
    execute_command = "sudo sh -eu '{{ .Path }}'"
    scripts = [
      "${path.root}/scripts/base.sh",
      "${path.root}/scripts/cleanup.sh",
    ]
  }
}
