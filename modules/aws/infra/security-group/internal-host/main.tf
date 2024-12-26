
locals {
  raw_config = yamldecode(file(var.config_file))
  config = {
    environment = lookup(local.raw_config.environments, var.environment, "Error: Invalid Environment!")
  }
  common_tags = {
    Environment = var.environment
    Managed-By = "tf"
  }
}

variable "environment" {}
variable "config_file" {}

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

resource "aws_security_group" "allow_ssh_within_vpc_and_outbound" {
  name        = "internal-host-sg"
  description = "Allow SSH within VPC and Allow all Outbound"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge (
    {
      Name = "internal-host-sg"    
    }, 
    local.common_tags
  )
}

resource "aws_security_group_rule" "allow_ssh_within_vpc" {
  type              = "ingress"
  description       = "Allow SSH within VPC ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [local.config.environment.cidr_block]
  security_group_id = aws_security_group.allow_ssh_within_vpc_and_outbound.id
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  description       = "Allow all outbound egress"
  from_port         = 0
  to_port           = 65535
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_ssh_within_vpc_and_outbound.id
}