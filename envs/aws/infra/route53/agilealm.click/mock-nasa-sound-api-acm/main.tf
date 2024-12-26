# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

module "aws_route53_agilealm_click_mock_nasa_sound_api_acm" {
  source = "../../../../../../modules/aws/infra/route53/acm"
  domain_name = "agilealm.click"
  record_name = "mock-nasa-sound-api"
}

terraform {
  backend "s3" {
    key = "envs/aws/infra/route53/agilealm.click/mock-nasa-sound-api-acm/terraform.state"
  }
}