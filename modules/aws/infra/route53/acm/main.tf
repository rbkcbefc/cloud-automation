variable "domain_name" {}
variable "record_name" {}

data "aws_route53_zone" "hosted-zone" {
  name = var.domain_name
}

resource "aws_acm_certificate" "certificate-request" {
  domain_name               = "${var.domain_name}"
  subject_alternative_names = ["${var.record_name}.${var.domain_name}"]
  validation_method         = "DNS"
  
  tags = {
    Name: "${var.domain_name}"
  }
}

resource "aws_route53_record" "validation-record" {
  for_each = {
    for dvo in aws_acm_certificate.certificate-request.domain_validation_options: dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = data.aws_route53_zone.hosted-zone.id
}

resource "aws_acm_certificate_validation" "certificate-validation" {
  certificate_arn         = aws_acm_certificate.certificate-request.arn
  validation_record_fqdns = [for record in aws_route53_record.validation-record: record.fqdn]
}