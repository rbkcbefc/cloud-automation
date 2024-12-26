locals {
  raw_config = yamldecode(file(var.config_file))
  config = {
    environment = lookup(local.raw_config.environments, var.environment, "Error: Invalid Environment!")
  }
  common_tags = {
    Environment = var.environment
    Managed-By  = "tf"  
  }
}

variable "environment" {}
variable "config_file" {}
variable "vpc_name" {}
variable "key_name" {}
variable "name_prefix" {}
variable "name_tag" {}
variable "ami_id" {}
variable "instance_type" {}
variable "iam_instance_profile_name" {}
variable "rendered_user_data" {}

provider "aws" {
  region = local.config.environment.region
}

data "aws_vpc" "selected" {
  filter {
    name = "tag:Name"
    values = [var.vpc_name]
  }
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "volume_type" {
  default = "gp3"
}

variable "volume_size" {
    default = 25
}

variable "block_device_name" {
  default = "/dev/xvda"
}

resource "aws_launch_template" "lt" {
  #name_prefix   = var.name_prefix
  name = var.name_tag
  image_id      = var.ami_id
  instance_type = var.instance_type

  key_name               = var.key_name
  vpc_security_group_ids = var.vpc_security_group_ids
  
  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  block_device_mappings {
    device_name = var.block_device_name
    ebs {
      volume_size = var.volume_size
      volume_type = var.volume_type
    }
  } 

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name = var.name_tag
      },
      local.common_tags
    )
  }

  user_data = base64encode(var.rendered_user_data)

}

output "aws_launch_template_id" {
  value = aws_launch_template.lt.id
}