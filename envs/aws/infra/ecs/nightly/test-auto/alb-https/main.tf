# Note to Execute: tf init -backend-config=../../../../../backend-s3-nightly.conf

module "ecs_alb_test_auto_https" {
  source = "../../../../../../../modules/aws/infra/alb-https"
  domain_name = "agilealm.click"
  tg_name = "ecs-test-auto"
  alb_name = "ecs-test-auto"
}

terraform {
  backend "s3" {
    key = "envs/aws/infra/ecs/nightly/test-auto/alb-https/terraform.state"
  }
}