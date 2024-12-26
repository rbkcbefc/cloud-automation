locals {
  raw_config = yamldecode(file(var.config_file))
  config = {
    environment = lookup(local.raw_config.environments, var.environment, "Error: Invalid Environment!")
  }
  account_id = data.aws_caller_identity.current.account_id
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

data "aws_caller_identity" "current" {}

provider "aws" {
  region = local.config.environment.region
}

resource "aws_iam_role" "ecs-task-execution-role" {
  name = "ecs-task-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECSTaskExecution"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Condition = {
            ArnLike = {
              "aws:SourceArn":"arn:aws:ecs:us-west-2:${local.account_id}:*"
            },
            StringEquals = {
              "aws:SourceAccount":"${local.account_id}"
            }
         }
      },
    ]
  })
  tags = merge(
    {
      Name = "ecs-task-execution"
    },
    local.common_tags
  )
}

resource "aws_iam_instance_profile" "ecs-task-execution-profile" {
  name = "ecs-task-execution"
  role = aws_iam_role.ecs-task-execution-role.name
  tags = merge (
    {
      Name = "ecs-task-execution"
    },
    local.common_tags
  )
}

resource "aws_iam_policy_attachment" "ecs-task-execution-attach" {
  name       = "ecs-task-execution-attachment"
  roles      = [aws_iam_role.ecs-task-execution-role.name]
  # Amazon ECS managed policy
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}