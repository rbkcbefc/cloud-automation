# Note to Execute: tf init -backend-config=../../../../../backend-s3-nightly.conf

locals {
  config_file = format("%s/../../../../../aws-config.yml", path.module)
  raw_config = yamldecode(file(local.config_file))
  config = {
    environment = lookup(local.raw_config.environments, "nightly", "Error: Invalid Environment!")
  }
  curr_dir_name = "${basename(abspath(path.module))}"
  ansible_targets = format("tag_Name_actions_runner_%s", replace("${local.curr_dir_name}", "-", "_"))
  instance_name = "actions-runner-${local.curr_dir_name}"
}

data "aws_security_group" "internal_host_sg" {
  filter {
    name = "tag:Name"
    values = ["internal-host-sg"]
  }
}

data "aws_subnet" "private_subnet_1a" {
  filter {
    name = "tag:Name"
    values = ["vpc-nightly-private-us-east-1a"]
  }
}

variable "install_actions_runner" {
  default = true
}

module "actions_runner" {
  source = "../../../../../../../modules/aws/infra/ec2-instance"
  config_file = local.config_file
  environment = "nightly"
  instance_name = local.instance_name
  instance_type = "t4g.micro"
  cost_center = "infra"
  ami_id = local.config.environment.my_docker_ami # My latest Ubuntu Docker AMI
  key_name = local.config.environment.ec2_instance_key_name
  vpc_security_group_ids = [data.aws_security_group.internal_host_sg.id]
  subnet_id = data.aws_subnet.private_subnet_1a.id
  wait_for_ssh = false
}

# Wait for new instance initialization complete
resource "time_sleep" "wait_for_cloud_init_completion" {
  count = var.install_actions_runner ? 1 : 0
  create_duration = "1s" # setting to 1s becos AWS SSM has been configured to wait for cloud-init to complete
}

resource "null_resource" "run_ansible_playbook" {
  count = var.install_actions_runner ? 1 : 0
  depends_on    = [module.actions_runner, time_sleep.wait_for_cloud_init_completion]

  # allows to run this playbook during each apply. This playbook is idempotent.
  triggers = {
    always_run = timestamp()
  }

  # run the playbook to install and configure the action runner
  # the role waits for ssh connection/instance (delay 10 seconds & max wait 600 seconds) 
  provisioner "local-exec" {
    command     = format("ansible-playbook -i %s -e 'targets=%s' -u %s playbooks/setup-actions-runner.yml --extra-vars \"%s\" --extra-vars '%s' --ssh-common-args '-o \"ProxyCommand ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i %s -W %s -q %s@%s\"'", 
      local.config.environment.ansible_dynamic_inventory,
      local.ansible_targets,
      local.config.environment.ami_user,
      "github_repo=${local.curr_dir_name} runner_user=ubuntu",
      "@ansible-secret-vars.yml",
      local.config.environment.bastion_host_private_key_file_path,
      "%h:%p",
      local.config.environment.bastion_host_user,
      local.config.environment.bastion_host_name)
    working_dir = "${path.cwd}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Running destroy-time provisioner'"
  }

}

terraform {
  backend "s3" {
    key            = "envs/aws/infra/ec2-instances/nightly/actions-runner/mock-email-service/terraform.state"
  }
}