# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

module "aws_ecr_repository" {
  source = "../../../../../../modules/aws/infra/ecr"
  config_file = format("%s/../../../../aws-config.yml", path.module)
  environment = "nightly"
  ecr_repositories = [
    "mock-email-service", 
    "mock-nasa-sound-api-service"
  ]
}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/ecr/nightly/ecr-repos/terraform.state"
  }
}