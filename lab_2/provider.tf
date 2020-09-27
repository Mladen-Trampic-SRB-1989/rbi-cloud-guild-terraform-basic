provider "aws" {
  region                  = var.region
  shared_credentials_file = "/terraform/.creds/aws_config"
}

provider "aws" {
  alias                   = "replica"
  region                  = var.replica_region
  shared_credentials_file = "/terraform/.creds/aws_config"
}