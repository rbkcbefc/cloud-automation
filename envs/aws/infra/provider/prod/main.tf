module "infra_provider" {
  source = "../../../../modules/aws/infra/provider"
  config_file = format("%s/../../../aws-config.yml", path.module)
  environment = "prod"
}

# Before executing, comment-out this block. Once terraform plan and apply works fine, uncomment this section and re-run 'terraform init'. 
# When prompted for migration from local to S3, enter 'yes'.
# During first execution, this block is not commented-out. Otherwise, terraform plan/apply will fail. 
# tf init, tf plan , apply
terraform {
  backend "s3" {
    key            = "envs/aws/infra/provider/terraform.state-prod"
  }
}