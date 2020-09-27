variable "hcloud_token" {

}

variable "server_count" {
  type = object({
    hetzner = number
  })
}

variable "region" {
  default = "eu-central-1"
}
