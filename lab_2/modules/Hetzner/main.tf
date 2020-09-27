resource "hcloud_server" "docker_server" {
  count       = var.server_count
  name        = "terraform-workshop-${count.index}"
  image       = "ubuntu-18.04"
  server_type = "cx11"
  user_data   = templatefile("${path.module}/resources/Cloud-Init.yml.template", { name="terraform-workshop-${count.index}" })
  datacenter  = "nbg1-dc3"
}


