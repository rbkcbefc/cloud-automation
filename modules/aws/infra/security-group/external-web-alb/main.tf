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

data "aws_vpc" "selected" {
  filter {
    name = "tag:Name"
    values = [var.vpc_name]
  }
}

resource "aws_security_group" "external_web_alb" {
  name        = "external-web-alb"
  description = "Allow 80 and 443 accessible from Internet"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge (
    {
      Name = "external-web-alb"
    },
    local.common_tags
  )
}

resource "aws_security_group_rule" "allow_80_from_internet" {
  type              = "ingress"
  description       = "Allow 80 from Internet"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external_web_alb.id
}

resource "aws_security_group_rule" "allow_443_from_internet" {
  type              = "ingress"
  description       = "Allow 443 from Internet"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external_web_alb.id
}

resource "aws_security_group_rule" "allow_all_to_internet" {
  type              = "egress"
  description       = "External web outbound rule"
  from_port         = 0
  to_port           = 65535
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.external_web_alb.id  
}