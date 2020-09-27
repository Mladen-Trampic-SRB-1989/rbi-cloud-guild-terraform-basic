module "hetzner" {
  source       = "./modules/Hetzner"
  hcloud_token = var.hcloud_token
  server_count = var.server_count["hetzner"]
}

#module "aws" {
#  source       = "./modules/Amazon"
#  server_count = var.server_count["hetzner"]
#}

data "aws_route53_zone" "hosted_zone" {
  name         = "trampic.info."
}

resource "aws_route53_record" "www" {
  for_each = { for resource in module.hetzner.servers.* :  "${resource["name"]}"=> resource["ipv4_address"]}
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = each.key
  type    = "A"
  ttl     = "300"
  records = [each.value]
}