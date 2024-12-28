variable "domain_name" {}
variable "record_name" {}
variable "record_type" {
  default = "CNAME"
}
variable "ttl" {
  default = 300
}
variable "record_values" {}

data "aws_route53_zone" "my-domain" {
  name = var.domain_name
}

resource "aws_route53_record" "my-record" {
  zone_id = data.aws_route53_zone.my-domain.id
  name    = var.record_name
  type    = var.record_type
  ttl     = var.ttl
  records = var.record_values
}