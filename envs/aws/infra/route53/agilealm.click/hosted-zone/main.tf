# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

module "aws_route53_agilealm_click" {
  source = "../../../../../../modules/aws/infra/route53/hosted-zone"
  domain_name = "agilealm.click"
}

terraform {
  backend "s3" {
    key = "envs/aws/infra/route53/agilealm.click/hosted-zone/terraform.state"
  }
}
