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

variable "ec2_instances" {
  default = []
}
variable "asg_name" {
  default = null
}

variable "subnet_ids" {
  type = list(string)
  default = []
}

data "aws_vpc" "selected" {
  filter {
    name = "tag:Name"
    values = [var.vpc_name]
  }
}

# creating ALB
variable "alb_name" {}
variable "alb_security_groups" {}
variable "alb_internal" {
  default = true # Set this to true for external ALB
}
variable "alb_http_port" {}

resource "aws_alb" "alb" {
  name               = var.alb_name
  internal           = var.alb_internal
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = var.alb_security_groups
  ip_address_type    = "ipv4"
  idle_timeout       = 300

  tags = merge (
    {
      name = var.alb_name
    },
    local.common_tags
  )
}

resource "aws_alb_listener" "alb_listener_http" {
  load_balancer_arn = aws_alb.alb.arn
  port              = var.alb_http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group.arn
  }

  tags = merge(
  {
    Name = var.alb_name
  },
  local.common_tags
  )
}

# target group
variable "tg_name" {}
variable "tg_target_type" {
  default = "instance"
}
variable "tg_health_check_path" {
  default = "/"
}
variable "tg_health_check_port" {
  default = "traffic-port"
}

resource "aws_alb_target_group" "target_group" {
  name        = var.tg_name
  port        = var.alb_http_port
  protocol    = "HTTP"
  target_type = var.tg_target_type
  vpc_id      = data.aws_vpc.selected.id

  health_check {
    enabled             = true
    interval            = 10
    path                = var.tg_health_check_path
    port                = var.tg_health_check_port # this is the default value for dynamic container port
    protocol            = "HTTP"
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