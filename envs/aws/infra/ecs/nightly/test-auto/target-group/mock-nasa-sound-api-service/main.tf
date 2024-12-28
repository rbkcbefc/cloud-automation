# Note to Execute: tf init -backend-config=../../../../../../backend-s3-nightly.conf

locals {
  config_file = format("%s/../../../../../../aws-config.yml", path.module)
  raw_config = yamldecode(file(local.config_file))
  config = {
    environment = lookup(local.raw_config.environments, "nightly", "Error: Invalid Environment!")
  }
}

module "ecs_test_auto_mock_nasa_sound_api_svc_tg" {
  source = "../../../../../../../../modules/aws/infra/target-group"
  environment = "nightly"
  config_file = local.config_file
  vpc_name = local.config.environment.vpc_name
  asg_name = "ecs-test-auto"
  tg_name = "ecs-mock-nasa-sound-api-service"
  tg_port = 80
  tg_protocol = "HTTP"
  tg_health_check_path = "/mock-nasa-sound-api/index.jsp"
  tg_health_check_port = "traffic-port"
  tg_health_check_protocol = "HTTP"
}

terraform {
  backend "s3" {
    key = "envs/aws/infra/ecs/nightly/test-auto/target-group/mock-nasa-sound-api-service/terraform.state"
  }
}