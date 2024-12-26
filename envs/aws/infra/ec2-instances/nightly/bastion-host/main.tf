# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

locals {
  config_file = format("%s/../../../../aws-config.yml", path.module)
  raw_config = yamldecode(file(local.config_file))
  config = {
    environment = lookup(local.raw_config.environments, "nightly", "Error: Invalid Environment!")
  }
}

module "bastion_host" {
  source = "../../../../../../modules/aws/infra/ec2-instance"
  config_file = local.config_file
  environment = "nightly"
  instance_name = "nightly-bastion-host"
  instance_type = "t4g.nano"
  cost_center = "infra"
  ami_id = local.config.environment.my_base_ami # My latest Ubuntu Base AMI
  associate_public_ip_address = true
  key_name = local.config.environment.ec2_instance_key_name
  vpc_security_group_ids = [data.aws_security_group.bastion_host_sg.id]
  subnet_id = data.aws_subnet.public_subnet_1a.id
}

data "aws_security_group" "bastion_host_sg" {
  filter {
    name = "tag:Name"
    values = ["bastion-host-sg"]
  }
}

data "aws_subnet" "public_subnet_1a" {
  filter {
    name = "tag:Name"
    values = ["vpc-nightly-public-us-east-1a"]
  }
}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/ec2-instances/nightly/bastion-host/terraform.state"
  }
}