terraform {
  backend "s3" {
    key                     = "multi-cloud-demo.tfstate"
    shared_credentials_file = "/terraform/.creds/aws_config"
  }
}