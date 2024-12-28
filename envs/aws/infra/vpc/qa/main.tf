
module "infra_vpc" {
  source = "../../../../../modules/aws/infra/vpc"
  config_file = format("%s/../../../aws-config.yml", path.module)
  environment = "qa"
}

# tf init -backend-config=../../../backend-s3-qa.conf 
terraform {
  backend "s3" {
    key            = "envs/aws/infra/vpc/qa/terraform.state"
  }
}