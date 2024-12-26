# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

module "aws_iam_role_ec2_core" {
  source = "../../../../../../modules/aws/infra/iam-role/ec2-core"
  config_file = format("%s/../../../../aws-config.yml", path.module)
  environment = "nightly"
}

terraform {
  backend "s3" {
    key = "envs/aws/infra/iam-role/nightly/ec2-core/terraform.state"
  }
}