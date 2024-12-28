# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

module "aws_security_ecs_host_bridge_network" {
  source = "../../../../../../modules/aws/infra/security-group/ecs-host-bridge-network"
  config_file = format("%s/../../../../aws-config.yml", path.module)
  environment = "nightly"
  vpc_name = "vpc-nightly"
}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/security-group/nightly/ecs-host-bridge-network/terraform.state"
  }
}