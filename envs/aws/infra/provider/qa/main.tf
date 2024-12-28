module "infra_provider" {
  source = "../../../../modules/aws/infra/provider"
  config_file = format("%s/../../../aws-config.yml", path.module)
  environment = "qa"
}

# Check-out the comments in file: ../nightly/main.tf ( backend s3 section )
# Run 1: tf init -backend-config=../../../backend-s3-qa.conf 
# Run 2: tf plan  
# Run 3: tf apply 
terraform {
   backend "s3" {
     key            = "envs/aws/infra/provider/terraform.state-qa"
   }
}