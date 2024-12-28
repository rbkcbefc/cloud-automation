# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

module "aws_security_group_external_web_alb" {
  source = "../../../../../../modules/aws/infra/security-group/external-web-alb"
  config_file = format("%s/../../../../aws-config.yml", path.module)
  environment = "nightly"
  vpc_name = "vpc-nightly"
}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/security-group/nightly/external-web-alb/terraform.state"
  }
}