# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

module "aws_ssm_document_cloud_init_wait" {
  source = "../../../../../../modules/aws/infra/ssm-document/cloud-init-wait/"
  config_file = format("%s/../../../../aws-config.yml", path.module)
  environment = "nightly"
}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/ssm-document/nightly/cloud-init-wait/terraform.state"
  }
}