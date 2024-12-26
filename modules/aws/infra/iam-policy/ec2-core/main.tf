locals {
  raw_config = yamldecode(file(var.config_file))
  config = {
    environment = lookup(local.raw_config.environments, var.environment, "Error: Invalid Environment!")
  }
  ec2_core_policy_file = "${path.module}/iam-policy.json.tpl"
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

resource "aws_iam_policy" "ec2-core-policy" {
  name        = "ec2-core-policy"
  description = "Provides basic permission to access EC2, Route53, S3 & ECR"
  policy = templatefile(local.ec2_core_policy_file, {})
  tags = merge (
    {
      Name = "ec2-core-policy"
    },
    local.common_tags
  )
}

output "aws_iam_policy_arn" {
  value = aws_iam_policy.ec2-core-policy.arn
}