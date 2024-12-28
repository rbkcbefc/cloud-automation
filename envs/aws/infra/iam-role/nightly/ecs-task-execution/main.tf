# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

module "aws_iam_role_ecs_task_execution" {
  source = "../../../../../../modules/aws/infra/iam-role/ecs-task-execution"
  config_file = format("%s/../../../../aws-config.yml", path.module)
  environment = "nightly"
}

terraform {
  backend "s3" {
    key = "envs/aws/infra/iam-role/nightly/ecs-task-execution/terraform.state"
  }
}