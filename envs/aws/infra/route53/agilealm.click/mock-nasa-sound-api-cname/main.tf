# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

locals {
  config_file = format("%s/../../../../aws-config.yml", path.module)
  raw_config = yamldecode(file(local.config_file))
  config = {
    environment = lookup(local.raw_config.environments, "nightly", "Error: Invalid Environment!")
  }
}

data "aws_alb" "test-auto-alb" {
  name = "ecs-test-auto"
}

module "aws_route53_agilealm_click_mock_nasa_sound_api_cname" {
  source = "../../../../../../modules/aws/infra/route53/simple-routing-policy"
  domain_name = "agilealm.click"
  record_name = "mock-nasa-sound-api"
  record_type = "CNAME"
  record_values = ["ecs-test-auto-420949230.us-east-1.elb.amazonaws.com"]
}

terraform {
  backend "s3" {
    key = "envs/aws/infra/route53/agilealm.click/mock-nasa-sound-api-cname/terraform.state"
  }
}