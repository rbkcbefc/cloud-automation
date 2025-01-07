# Note to Execute: tf init -backend-config=../../../../../backend-s3-nightly.conf

locals {
  config_file = format("%s/../../../../../aws-config.yml", path.module)
  raw_config = yamldecode(file(local.config_file))
  config = {
    environment = lookup(local.raw_config.environments, "nightly", "Error: Invalid Environment!")
  }
  curr_dir_name = "${basename(abspath(path.module))}"
  ansible_targets = format("tag_Name_actions_runner_%s", replace("${local.curr_dir_name}", "-", "_"))
  instance_name = "actions-runner-${local.curr_dir_name}"
}


module "actions_runner" {
  source = "../../../../../../../modules/aws/infra/ec2-instance"
  config_file = local.config_file
  environment = "nightly"
  instance_name = "${local.instance_name}"
  instance_type = "t4g.micro"
  cost_center = "infra"
  ami_id = local.config.environment.my_docker_ami # My latest Ubuntu Docker AMI
  key_name = local.config.environment.ec2_instance_key_name
  vpc_security_group_ids = [data.aws_security_group.internal_host_sg.id]
  subnet_id = data.aws_subnet.private_subnet_1a.id
  wait_for_ssh = false
}

data "aws_security_group" "internal_host_sg" {
  filter {
    name = "tag:Name"
    values = ["internal-host-sg"]
  }
}

data "aws_subnet" "private_subnet_1a" {
  filter {
    name = "tag:Name"
    values = ["vpc-nightly-private-us-east-1a"]
  }
}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/ec2-instances/nightly/actions-runner/mock-nasa-sound-api-service/terraform.state"
  }
}