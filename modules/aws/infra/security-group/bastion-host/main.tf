
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

provider "aws" {
  region = local.config.environment.region
}

variable "vpc_name" {}
variable "whitelisted_ips" {
  type = list(string)
}

data "aws_vpc" "selected" {
  filter {
    name = "tag:Name"
    values = [var.vpc_name]
  }
}

resource "aws_security_group" "bastion_host_sg" {
  name        = "bastion-host-sg"
  description = format("%s %s %s", "Allow SSH to", var.environment, "Bastion Host")
  vpc_id      = data.aws_vpc.selected.id

  tags = merge ( 
    {
      Name = "bastion-host-sg"
    },
    local.common_tags
  )
}

resource "aws_security_group_rule" "bastion_host_in" {
  type              = "ingress"
  description       = "Bastion host ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.whitelisted_ips
  security_group_id = aws_security_group.bastion_host_sg.id
}

resource "aws_security_group_rule" "bastion_host_out" {
  type              = "egress"
  description       = "Bastion host egress"
  from_port         = 0
  to_port           = 65535
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_host_sg.id  
}