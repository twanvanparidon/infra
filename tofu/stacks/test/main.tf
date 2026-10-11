# Test stack: proves state encryption and the plan and apply pipeline. It
# creates no real infrastructure.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

resource "terraform_data" "test" {
  input = "applied from ci"
}
