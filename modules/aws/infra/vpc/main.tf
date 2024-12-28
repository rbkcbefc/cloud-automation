locals {
  raw_config = yamldecode(file(var.config_file))
  config = {
    environment = lookup(local.raw_config.environments, var.environment, "Error: Invalid Environment!")
  }
  common_tags = {
    Environment = var.environment
    Managed-By = "tf"
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

output "vpc_name" {
  value = local.config.environment.vpc_name
}

output "cidr_block" {
  value = local.config.environment.cidr_block
}

output "azs" {
  value = flatten(local.config.environment["azs"])
}

output "private_subnets" {
  value = flatten(local.config.environment["private_subnets"])
}

output "public_subnets" {
  value = flatten(local.config.environment["public_subnets"])
}

output "enable_nat_gateway" {
  value = local.config.environment.enable_nat_gateway
}

output "enable_vpn_gateway" {
  value = local.config.environment.enable_vpn_gateway
}

resource "null_resource" "show_config" {
  for_each = toset(local.config.environment["azs"])
  provisioner "local-exec" {
    command = <<EOF
      echo "VPC Name: ${local.config.environment.vpc_name} , \
      CIDR Block: ${local.config.environment.cidr_block} , \
      AZ: ${each.key}"
    EOF
  }
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.config.environment.vpc_name
  cidr = local.config.environment.cidr_block

  azs             = toset(local.config.environment["azs"])
  private_subnets = toset(local.config.environment["private_subnets"])
  public_subnets  = toset(local.config.environment["public_subnets"])

  enable_nat_gateway = local.config.environment.enable_nat_gateway
  enable_vpn_gateway = local.config.environment.enable_vpn_gateway

  tags = merge (
    {
      Name = local.config.environment.vpc_name
    },
    local.common_tags
  )
}