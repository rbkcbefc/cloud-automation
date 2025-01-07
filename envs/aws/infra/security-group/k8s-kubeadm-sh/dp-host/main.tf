# Note to Execute: tf init -backend-config=../../../../config/backend-s3-k8s-kubeadm-sh.conf

module "aws_security_group_k8s_dp_host" {
  source = "../../../../../../modules/aws/infra/security-group/k8s-kubeadm-sh-dp-host"
  config_file = format("%s/../../../../config/k8s-kubeadm-sh.yml", path.module)
  environment = "k8s-kubeadm-sh"
  vpc_name = "vpc-nightly"
  # Note: This SG allows SSH & all incoming from VPC and all outbound access.
}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/security-group/k8s-kubeadm-sh/k8s-kubeadm-sh-dp-host/terraform.state"
  }
}