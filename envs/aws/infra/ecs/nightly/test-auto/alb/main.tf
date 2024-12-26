# Note to Execute: tf init -backend-config=../../../../../backend-s3-nightly.conf

locals {
  config_file = format("%s/../../../../../aws-config.yml", path.module)
  raw_config = yamldecode(file(local.config_file))
  config = {
    environment = lookup(local.raw_config.environments, "nightly", "Error: Invalid Environment!")
  }
}

data "aws_subnet" "public_subnet_1a" {
  filter {
    name = "tag:Name"
    values = ["vpc-nightly-public-us-east-1a"]
  }
}

data "aws_subnet" "public_subnet_1b" {
  filter {
    name = "tag:Name"
    values = ["vpc-nightly-public-us-east-1b"]
  }
}

data "aws_subnet" "public_subnet_1c" {
  filter {
    name = "tag:Name"
    values = ["vpc-nightly-public-us-east-1c"]
  }
}

data "aws_launch_template" "ecs_test_auto" {
    name = "ecs-test-auto"
}

data "aws_security_group" "external_web_alb" {
  filter {
    name = "tag:Name"
    values = ["external-web-alb"]
  }
}

module "ecs_asg_test_auto" {
  source = "../../../../../../../modules/aws/infra/alb"
  environment = "nightly"
  config_file = local.config_file
  asg_name = "ecs-test-auto"
  alb_name = "ecs-test-auto"
  alb_http_port = 80
  subnet_ids = [
    data.aws_subnet.public_subnet_1a.id,
    data.aws_subnet.public_subnet_1b.id,
  ]
  alb_security_groups = [data.aws_security_group.external_web_alb.id]
  alb_internal = false
  tg_name = "ecs-test-auto"
  tg_health_check_path = "/mock-nasa-sound-api/index.jsp"
  vpc_name = local.config.environment.vpc_name
}

terraform {
  backend "s3" {
    key = "envs/aws/infra/ecs/nightly/test-auto/alb/terraform.state"
  }
}