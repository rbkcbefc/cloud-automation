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
variable "cluster_name" {}
variable "asg_arn" {}
variable "target_capacity" {}
variable "capacity_provider_name" {} # Do not prefix: aws/ecs/fargate

variable "max_step_size" {
  default = 1000
}

variable "min_step_size" {
  default = 1
}

resource "aws_ecs_cluster" "ecs_cluster" {
 name = var.cluster_name
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = var.capacity_provider_name

  auto_scaling_group_provider {
    auto_scaling_group_arn = var.asg_arn

    managed_scaling {
      maximum_scaling_step_size = var.max_step_size
      minimum_scaling_step_size = var.min_step_size
      status                    = "ENABLED"
      target_capacity           = var.target_capacity
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs_capacity_providers" {
  cluster_name = var.cluster_name

  capacity_providers = [aws_ecs_capacity_provider.ecs_capacity_provider.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
  }
}