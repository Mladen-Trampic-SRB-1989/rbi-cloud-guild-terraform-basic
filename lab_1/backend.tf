terraform {
  backend "local" {
    path = ".terraform_state/terraform_s3_backend.tfstate"
  }
}