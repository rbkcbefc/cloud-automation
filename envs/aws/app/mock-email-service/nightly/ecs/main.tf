# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

locals {
  config_file = format("%s/../../../../aws-config.yml", path.module)
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

data "aws_subnet" "private_subnet_1c" {
  filter {
    name = "tag:Name"
    values = ["vpc-nightly-private-us-east-1c"]
  }
}

data "aws_security_group" "internal_host_sg" {
  filter {
    name = "tag:Name"
    values = ["internal-host-sg"]
  }
}

data "aws_security_group" "ecs_host_bridge_network" {
  filter {
    name = "tag:Name"
    values = ["ecs-host-bridge-network"]
  }
}

data "aws_alb_target_group" "selected" {
  name = "ecs-mock-email-service"
}

module "ecs_service_mock-email-service" {
  source = "../../../../../../modules/aws/infra/ecs/service"
  environment = "nightly"
  config_file = local.config_file
  vpc_name = local.config.environment.vpc_name
  cluster_name = "test-auto"
  service_name = "mock-email-service"
  ecr_repo_name = "mock-email-service"
  service_version = "c2e756b-2024-12-14-01-19"
  ecs_role = local.config.environment.ecs_task_execution_profile_name
  desired_count = 1
  subnet_ids = [
    data.aws_subnet.private_subnet_1a.id,
    data.aws_subnet.private_subnet_1b.id,
  ]
  security_group_ids = [
    data.aws_security_group.internal_host_sg.id,
    data.aws_security_group.ecs_host_bridge_network.id
  ]
  target_group_arn = data.aws_alb_target_group.selected.arn
  ecs_capacity_provider_name = "asg-test-auto"
  cpu_arch = local.config.environment.cpu_arch
}

terraform {
  backend "s3" {
    key = "envs/aws/app/mock-email-service/nightly/ecs/terraform.state"
  }
}