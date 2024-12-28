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
variable "launch_template_id" {}
variable "asg_name" {}

variable "launch_template_version" {
    default = "$Latest" # Other Option: $Default
}

variable "desired_capacity" {
  default = 2
}

variable "max_size" {
  default = 3
}

variable "min_size" {
  default = 1
}

variable "termination_policies" {
  default = ["OldestInstance"]
}

variable "subnet_ids" {
  type = list(string)
}

resource "aws_autoscaling_group" "asg" {

  name                = var.asg_name
  vpc_zone_identifier = var.subnet_ids
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  termination_policies= var.termination_policies

  launch_template {
     id      = var.launch_template_id
     version = var.launch_template_version
  }

  instance_refresh {
    strategy = "Rolling"
  }

  lifecycle { 
    ignore_changes = [desired_capacity, min_size, max_size]
  }

  tag {
    key                 = "Name"
    value               = var.asg_name
    propagate_at_launch = true
  }

}

resource "aws_autoscaling_group_tag" "asg_tags" {
  for_each = { for k, v in local.common_tags : k => v }
  autoscaling_group_name = var.asg_name
  tag {
    key                 = each.key
    value               = each.value
    propagate_at_launch = false
  }
  depends_on = [ aws_autoscaling_group.asg ]
}