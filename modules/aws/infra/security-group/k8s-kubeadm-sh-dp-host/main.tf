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

resource "aws_security_group" "k8s-kubeadm-sh-dp-host" {
  name        = "k8s-kubeadm-sh-dp-host"
  description = "Allow all inbound from VPC and all outbound. SSH from VPC"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge (
    {
      Name = "k8s-kubeadm-sh-dp-host"
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
  security_group_id = aws_security_group.k8s-kubeadm-sh-dp-host.id
}

resource "aws_security_group_rule" "allow_all_inbound_from_vpc" {
  type              = "ingress"
  description       = "Allow all inbound egress from VPC"
  from_port         = 0
  to_port           = 65535
  protocol          = -1
  cidr_blocks       = [local.config.environment.cidr_block]
  security_group_id = aws_security_group.k8s-kubeadm-sh-dp-host.id
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  description       = "Allow all outbound egress"
  from_port         = 0
  to_port           = 65535
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s-kubeadm-sh-dp-host.id
}