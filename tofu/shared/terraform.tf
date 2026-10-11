# Shared by every stack through a symlink: the OpenTofu version, and
# encryption of state and plan files. The key provider comes from
# TF_ENCRYPTION, see .taskfiles/tofu.
terraform {
  required_version = "~> 1.13"

  encryption {
    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }

    state {
      method   = method.aes_gcm.main
      enforced = true
    }

    plan {
      method   = method.aes_gcm.main
      enforced = true
    }
  }
}
