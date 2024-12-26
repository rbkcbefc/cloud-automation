# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

module "aws_security_group_internal_host" {
  source = "../../../../../../modules/aws/infra/security-group/internal-host"
  config_file = format("%s/../../../../aws-config.yml", path.module)
  environment = "nightly"
  vpc_name = "vpc-nightly"
  # Note: This SG allows SSH within VPC and all outbound access.
}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/security-group/nightly/internal-host/terraform.state"
  }
}