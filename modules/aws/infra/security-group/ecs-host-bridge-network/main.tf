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

variable "environment" {
  type = string
  description = "Name of the environment"
  default = null
}

variable "config_file" {
  default = null
}

provider "aws" {
  region = local.config.environment.region
}

variable "vpc_name" {}

data "aws_vpc" "selected" {
  filter {
    name = "tag:Name"
    values = [var.vpc_name]
  }
}

resource "aws_security_group" "ecs_host_bridge_network" {
  name        = "ecs-host-bridge-network"
  description = "Allow all TCP from VPC "
  vpc_id      = data.aws_vpc.selected.id

  tags = merge (
    {
      Name = "ecs-host-bridge-network"
    },
    local.common_tags
  )
}

resource "aws_security_group_rule" "allow_all_tcp_from_vpc" {
  type              = "ingress"
  description       = "Allow all TCP from VPC"
  from_port         = 0
  to_port           = 65535
  protocol          = "TCP"
  cidr_blocks       = [local.config.environment.cidr_block]
  security_group_id = aws_security_group.ecs_host_bridge_network.id
}