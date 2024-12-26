# Note to Execute: tf init -backend-config=../../../../../backend-s3-nightly.conf

locals {
  config_file = format("%s/../../../../../aws-config.yml", path.module)
  raw_config = yamldecode(file(local.config_file))
  config = {
    environment = lookup(local.raw_config.environments, "nightly", "Error: Invalid Environment!")
  }
}

data "aws_subnet" "private_subnet_1a" {
  filter {
    name = "tag:Name"
    values = ["vpc-nightly-private-us-east-1a"]
  }
}

data "aws_subnet" "private_subnet_1b" {
  filter {
    name = "tag:Name"
    values = ["vpc-nightly-private-us-east-1b"]
  }
}

data "aws_launch_template" "ecs-test-auto" {
    name = "ecs-test-auto"
}

module "ecs_asg_test_auto" {
  source = "../../../../../../../modules/aws/infra/asg"
  environment = "nightly"
  config_file = local.config_file
  launch_template_id = data.aws_launch_template.ecs-test-auto.id
  asg_name = "ecs-test-auto"
  subnet_ids = [
    data.aws_subnet.private_subnet_1a.id,
    data.aws_subnet.private_subnet_1b.id,
  ]
  desired_capacity = 1
  max_size = 2
  min_size = 1
}

terraform {
  backend "s3" {
    key = "envs/aws/infra/ecs/nightly/test-auto/asg/terraform.state"
  }
}