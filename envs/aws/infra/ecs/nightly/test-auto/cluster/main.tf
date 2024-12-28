# Note to Execute: tf init -backend-config=../../../../../backend-s3-nightly.conf

locals {
  config_file = format("%s/../../../../../aws-config.yml", path.module)
  raw_config = yamldecode(file(local.config_file))
  config = {
    environment = lookup(local.raw_config.environments, "nightly", "Error: Invalid Environment!")
  }
}

data "aws_autoscaling_group" "selected" {
  name = "ecs-test-auto"
}

module "ecs_cluster_test_auto" {
  source = "../../../../../../../modules/aws/infra/ecs/cluster"
  environment = "nightly"
  config_file = local.config_file
  vpc_name = local.config.environment.vpc_name
  cluster_name = "test-auto"
  asg_arn = data.aws_autoscaling_group.selected.arn
  target_capacity = 3
  capacity_provider_name = "asg-test-auto"
}
