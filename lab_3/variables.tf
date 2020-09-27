variable "region" {
  default = "eu-central-1"
}

variable "replica_region" {
  default = "eu-west-1"
}

variable "accounts" {
  type    = list(string)
  default = []
}