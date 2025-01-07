# Note to Execute: tf init -backend-config=../../../../backend-s3-nightly.conf

module "aws_security_group_bastion_host" {
  source = "../../../../../../modules/aws/infra/security-group/bastion-host"
  config_file = format("%s/../../../../aws-config.yml", path.module)
  environment = "nightly"
  vpc_name = "vpc-nightly"
  whitelisted_ips = ["207.62.191.10/32", "73.70.120.200/32","172.56.46.39/32",
                    "96.68.157.161/32", "76.126.231.192/32", "67.169.84.105/32"
                    ]
}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/security-group/nightly/bastion-host/terraform.state"
  }
}