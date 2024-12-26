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

data "aws_iam_policy" "ec2-core-policy"{
  name = "ec2-core-policy"
}

provider "aws" {
  region = local.config.environment.region
}

resource "aws_iam_role" "ec2-core-role" {
  name = "ec2-core-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Core"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = ["ec2.amazonaws.com", "ssm.amazonaws.com"]
        }
      },
    ]
  })
  tags = merge(
    {
      Name = "ec2-core-role"
    },
    local.common_tags
  )
}

resource "aws_iam_instance_profile" "ec2-core-profile" {
  name = "ec2-core-profile"
  role = aws_iam_role.ec2-core-role.name
  tags = merge (
    {
      Name = "ec2-core-profile"
    },
    local.common_tags
  )
}

resource "aws_iam_policy_attachment" "ec2-core-attach" {
  name       = "ec2-core-attachment"
  roles      = [aws_iam_role.ec2-core-role.name]
  policy_arn = data.aws_iam_policy.ec2-core-policy.arn
}

resource "aws_iam_policy_attachment" "ec2-core-ssm-attach" {
  name       = "ec2-core-attachment"
  roles      = [aws_iam_role.ec2-core-role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
}

resource "aws_iam_policy_attachment" "ec2-core-cloudwatch-agent-attach" {
  name       = "ec2-core-attachment"
  roles      = [aws_iam_role.ec2-core-role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}