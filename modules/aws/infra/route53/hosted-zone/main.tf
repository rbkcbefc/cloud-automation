variable "domain_name" {}

resource "aws_route53_zone" "my-domain" {
  name = var.domain_name
}