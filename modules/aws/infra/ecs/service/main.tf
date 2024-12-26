locals {
  raw_config = yamldecode(file(var.config_file))
  config = {
    environment = lookup(local.raw_config.environments, var.environment, "Error: Invalid Environment!")
  }
  account_id = data.aws_caller_identity.selected.account_id
  region = data.aws_region.selected
  common_tags = {
    Environment = var.environment
    Managed-By  = "tf"  
  }
}

variable "environment" {}
variable "config_file" {}
variable "vpc_name" {}
variable "cluster_name" {}
variable "service_name" {}
variable "ecr_repo_name" {}
variable "service_version" {}

variable "cpu" {
  default = 1024
}
variable "memory" {
  default = 512
}
variable "cpu_arch" {
  default = "X86_64" # ARM64
}
variable "container_port" {
  default = 8080
}
variable "host_port" {
  default = 0 # dynamic host:container port mapping
}
variable "service_launch_type" {
  default = "EC2"
}
variable "task_network_mode" {
  default = "bridge"
}
variable "ecs_role" {}

data "aws_caller_identity" "selected" {}
data "aws_region" "selected" {}

data "aws_ecs_cluster" "selected" {
  cluster_name = var.cluster_name
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family             = "${var.service_name}-task"
  requires_compatibilities = [var.service_launch_type]
  network_mode       = var.task_network_mode
  task_role_arn = "arn:aws:iam::${local.account_id}:role/${var.ecs_role}"
  cpu                = var.cpu
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_arch
  }
  container_definitions = jsonencode([{
     name      = var.service_name
     image     = "${local.account_id}.dkr.ecr.${local.config.environment.region}.amazonaws.com/${var.ecr_repo_name}:${var.service_version}"
     cpu       = var.cpu
     memory    = var.memory
     essential = true
     portMappings = [
       {
         containerPort = var.container_port
         hostPort      = var.host_port
         protocol      = "tcp"
       }
     ],
    #  logConfiguration = {
    #    logDriver= "awslogs",
    #      options = {
    #        awslogs-group = "${var.service_name}-logs",
    #        awslogs-create-group = "true",
    #        awslogs-region = local.config.environment.region,
    #        awslogs-stream-prefix = "ecs"
    #     }
    #   }
    }
 ])
}

variable "desired_count" {}
variable "subnet_ids" {}
variable "security_group_ids" {}
variable "target_group_arn" {}
variable "ecs_capacity_provider_name" {}

variable "deployment_minimum_healthy_percent" {
  default = 0
}
variable "deployment_maximum_percent" {
  default = 200
}

resource "aws_ecs_service" "ecs_service" {
  name            = var.service_name
  cluster         = data.aws_ecs_cluster.selected.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = var.desired_count

  #iam_role = "ec2-core"
  #iam_role = "ecs-task-execution"
  # network_configuration {
  #   assign_public_ip = false
  #   subnets         = var.subnet_ids
  #   security_groups = var.security_group_ids
  # }

  force_new_deployment = true 

  triggers = {
    redeployment = timestamp()
  }

  capacity_provider_strategy {
    capacity_provider = var.ecs_capacity_provider_name
    weight            = 100
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent = var.deployment_maximum_percent
}