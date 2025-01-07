# Note to Execute: tf init -backend-config=../../../../config/backend-s3-k8s-kubeadm-sh.conf

locals {
  config_file = format("%s/../../../../../aws/config/k8s-kubeadm-sh.yml", path.module)
  raw_config = yamldecode(file(local.config_file))
  config = {
    environment = lookup(local.raw_config.environments, "k8s-kubeadm-sh", "Error: Invalid Environment!")
  }
  curr_dir_name = "${basename(abspath(path.module))}"
  ansible_targets = format("tag_Name_k8s_kubeadm_sh_%s", replace("${local.curr_dir_name}", "-", "_"))
  instance_name = "k8s-kubeadm-sh-${local.curr_dir_name}"
}

data "aws_security_group" "k8s-kubeadm-sh-cp-host" {
  filter {
    name = "tag:Name"
    values = ["k8s-kubeadm-sh-cp-host"]
  }
}

data "aws_subnet" "public-subnet-1a" {
  filter {
    name = "tag:Name"
    values = ["vpc-nightly-public-us-east-1a"]
  }
}

module "k8s_kubeadm_sh_cp_node" {
  source = "../../../../../../modules/aws/infra/ec2-instance"
  config_file = local.config_file
  environment = "k8s-kubeadm-sh"
  instance_name = local.instance_name
  instance_type = "t4g.medium"
  cost_center = "infra"
  ami_id = local.config.environment.my_containerd_ami # My latest Ubuntu Docker AMI
  key_name = local.config.environment.ec2_instance_key_name
  vpc_security_group_ids = [data.aws_security_group.k8s-kubeadm-sh-cp-host.id]
  subnet_id = data.aws_subnet.public-subnet-1a.id
  volume_size = "20"
  wait_for_ssh = false
  associate_public_ip_address = true
}

# Wait for new instance initialization complete
resource "time_sleep" "wait-for-cloud-init-completion" {
  create_duration = "10s" # setting to 1s becos AWS SSM has been configured to wait for cloud-init to complete
}

resource "null_resource" "run-ansible-playbook" {
  depends_on    = [module.k8s_kubeadm_sh_cp_node, time_sleep.wait-for-cloud-init-completion]

  # this playbook is only run/executed during first apply because it does "kubeadm init"
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command     = format("ansible-playbook -vv -i %s -e 'targets=%s' -u %s playbooks/setup-k8s-kubeadm-sh.yml --extra-vars \"%s\" --extra-vars \"current_node_name=%s\" --extra-vars \"control_plane_host=%s\" --extra-vars '%s' --ssh-common-args '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i %s'", 
      local.config.environment.ansible_dynamic_inventory,
      local.ansible_targets,
      local.config.environment.ami_user,
      "ansible_user=ubuntu k8s_node_role=controlplane",
      local.instance_name,
      "${module.k8s_kubeadm_sh_cp_node.host_public_ip}",
      "@ansible-secret-vars.yml",
      local.config.environment.bastion_host_private_key_file_path)
    working_dir = "${path.cwd}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Running destroy-time provisioner'"
  }

}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/k8s/kubeadm-sh/cp-node/terraform.state"
  }
}