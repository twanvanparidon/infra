# Test stack: proves state encryption and the plan and apply pipeline. It
# creates no real infrastructure.
terraform {
  required_version = "~> 1.13"

  backend "local" {
    path = "terraform.tfstate"
  }

  # The key provider comes from TF_ENCRYPTION; see .taskfiles/tofu.
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

resource "terraform_data" "test" {
  input = "test"
}
