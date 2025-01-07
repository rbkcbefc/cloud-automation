# Note to Execute: tf init -backend-config=../../../../../backend-s3-k8s-kubeadm-sh.conf

module "aws_security_group_k8s_cp_host" {
  source = "../../../../../../modules/aws/infra/security-group/k8s-kubeadm-sh-cp-host"
  config_file = format("%s/../../../../config/k8s-kubeadm-sh.yml", path.module)
  environment = "k8s-kubeadm-sh"
  vpc_name = "vpc-nightly"
  whitelisted_ips = ["207.62.191.10/32", "73.70.120.200/32","172.56.46.39/32",
                    "96.68.157.161/32", "76.126.231.192/32", "67.169.84.105/32"
                    ]
  # Note: This SG allows SSH & all incoming from VPC and all outbound access.
  # Note: Allow incoming 443 from outside world.
}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/security-group/k8s-kubeadm-sh/k8s-kubeadm-sh-cp-host/terraform.state"
  }
}