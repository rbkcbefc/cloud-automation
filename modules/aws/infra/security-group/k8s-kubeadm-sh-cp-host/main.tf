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
variable "whitelisted_ips" {
  type = list(string)
}

data "aws_vpc" "selected" {
  filter {
    name = "tag:Name"
    values = [var.vpc_name]
  }
}

resource "aws_security_group" "k8s-kubeadm-sh-cp-host" {
  name        = "k8s-kubeadm-sh-cp-host"
  description = "Allow 443 TCP from outside and all outbound. SSH from VPC"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge (
    {
      Name = "k8s-kubeadm-sh-cp-host"
    },
    local.common_tags
  )
}

resource "aws_security_group_rule" "allow_6443_tcp_from_outside" {
  type              = "ingress"
  description       = "Allow 6443 TCP from outside"
  from_port         = 6443
  to_port           = 6443
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s-kubeadm-sh-cp-host.id
}

resource "aws_security_group_rule" "allow_ssh_from_whitelist_ips" {
  type              = "ingress"
  description       = "Allow ssh from whitelist IPs"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.whitelisted_ips
  security_group_id = aws_security_group.k8s-kubeadm-sh-cp-host.id
}

resource "aws_security_group_rule" "allow_ssh_within_vpc" {
  type              = "ingress"
  description       = "Allow SSH within VPC ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [local.config.environment.cidr_block]
  security_group_id = aws_security_group.k8s-kubeadm-sh-cp-host.id
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  description       = "Allow all outbound egress"
  from_port         = 0
  to_port           = 65535
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s-kubeadm-sh-cp-host.id
}