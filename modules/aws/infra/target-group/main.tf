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
variable "asg_name" {}
variable "tg_name" {}
variable "tg_port" {}
variable "tg_protocol" {}
variable "tg_target_type" {
  default = "instance"
}
variable "tg_health_check_path" {
  default = "/"
}
variable "tg_health_check_port" {
  default = "traffic-port"
}
variable "tg_health_check_protocol" {
  default = "HTTP"
}

data "aws_vpc" "selected" {
  filter {
    name = "tag:Name"
    values = [var.vpc_name]
  }  
}

resource "aws_alb_target_group" "target_group" {
  name        = var.tg_name
  port        = var.tg_port
  protocol    = var.tg_protocol
  target_type = var.tg_target_type
  vpc_id      = data.aws_vpc.selected.id

  health_check {
    enabled             = true
    interval            = 10
    path                = var.tg_health_check_path
    port                = var.tg_health_check_port # this is the default value for dynamic container port
    protocol            = var.tg_health_check_protocol
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge (
    {
      Name = var.tg_name
    },
    local.common_tags
  )
}

#Autoscaling Attachment ( Dynamic Association )
resource "aws_autoscaling_attachment" "asg" {
  autoscaling_group_name = var.asg_name
  lb_target_group_arn = aws_alb_target_group.target_group.arn
}