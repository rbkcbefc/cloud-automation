# launch template , asg, alb, sg, listener, target group
# cluster, capacity provider

# Note to Execute: tf init -backend-config=../../../../../backend-s3-nightly.conf

locals {
  config_file = format("%s/../../../../../aws-config.yml", path.module)
  raw_config = yamldecode(file(local.config_file))
  config = {
    environment = lookup(local.raw_config.environments, "nightly", "Error: Invalid Environment!")
  }
}

module "ecs_launch_template_test_auto" {
  source = "../../../../../../../modules/aws/infra/launch-template"
  environment = "nightly"
  config_file = local.config_file
  vpc_name = local.config.environment.vpc_name
  key_name = local.config.environment.ec2_instance_key_name
  name_prefix = "ecs-test-auto"
  name_tag = "ecs-test-auto"
  instance_type = local.config.environment.ecs_instance_type
  iam_instance_profile_name = local.config.environment.ec2_instance_profile_name
  vpc_security_group_ids = [
    data.aws_security_group.internal_host_sg.id,
    data.aws_security_group.ecs_host_bridge_network.id
  ]
  ami_id = local.config.environment.my_aws_ecr_ecs_ami
  rendered_user_data = data.template_file.user_data.rendered
}

data "template_file" "user_data" {
  template = file("user_data.sh")
  vars = {
    ecs_cluster_name = "test-auto"
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

terraform {
  backend "s3" {
    key = "envs/aws/infra/ecs/nightly/test-auto/launch-template/terraform.state"
  }
}