module "infra_provider" {
  source = "../../../../../modules/aws/infra/provider"
  config_file = format("%s/../../../config/k8s-kubeadm-sh.yml", path.module)
  environment = "k8s-kubeadm-sh"
}

# When executing for the first-time, make sure below backend-s3 block is commented-out.
# # tf init, tf plan, tf apply
# Nexttime, un-comment this block.
# tf init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf 
# When prompted for migration from local to S3, enter 'yes'.
# tf plan
# tf apply

terraform {
  backend "s3" {
    key            = "envs/aws/infra/provider/k8s-kubeadm-sh/terraform.state"
  }
}