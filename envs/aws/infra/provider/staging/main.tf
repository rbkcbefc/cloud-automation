module "infra_provider" {
  source = "../../../../modules/aws/infra/provider"
  config_file = format("%s/../../../aws-config.yml", path.module)
  environment = "staging"
}

# Check-out the comments in file: ../nightly/main.tf ( backend s3 section )
# Run 1: tf init -backend-config=../../../backend-s3-staging.conf 
# Run 2: tf plan -backend-config=../../../backend-s3-staging.conf 
# Run 3: tf apply -backend-config=../../../backend-s3-staging.conf 
terraform {
  backend "s3" {
    key            = "envs/aws/infra/provider/terraform.state-staging"
  }
}