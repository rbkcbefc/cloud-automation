locals {
  raw_config = yamldecode(file(var.config_file))
  config = {
    environment = lookup(local.raw_config.environments, var.environment, "Error: Invalid Environment!")
  }
  aws_account_id = data.aws_caller_identity.current.account_id
  lifecycle_policy_template_file = "lifecycle_policy.json.tpl"
  iam_policy_template_file = "iam_policy.json.tpl"
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

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

variable "ecr_repositories" {
  description = "ECR Repositories"
  type        = set(string)
  default     = null
}

resource "aws_ecr_repository" "repository" {
  for_each = var.ecr_repositories

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = merge (
    {
      Name = each.value
    },
    local.common_tags
  )
}

resource "aws_ecr_repository_policy" "repository_iam_policy" {
  for_each = aws_ecr_repository.repository
  repository = each.value.name
  policy = templatefile(local.iam_policy_template_file, {
    aws_account_id = local.aws_account_id
  })
}

resource "aws_ecr_lifecycle_policy" "repository_lifecycle_policy" {
  for_each = aws_ecr_repository.repository
  repository = each.value.name
  policy     = templatefile(local.lifecycle_policy_template_file, {})
}

resource "aws_ecr_registry_scanning_configuration" "scan_configuration" {
  scan_type = "ENHANCED"

  rule {
    scan_frequency = "CONTINUOUS_SCAN"
    repository_filter {
      filter      = "*"
      filter_type = "WILDCARD"
    }
  }
}