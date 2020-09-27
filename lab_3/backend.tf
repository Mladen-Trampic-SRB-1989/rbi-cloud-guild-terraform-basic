terraform {
  backend "s3" {
    key                     = "open-policy-agent-demo.tfstate"
    shared_credentials_file = "/terraform/.creds/aws_config"
  }
}