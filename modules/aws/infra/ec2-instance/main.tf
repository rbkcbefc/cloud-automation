locals {
  raw_config = yamldecode(file(var.config_file))
  config = {
    environment = lookup(local.raw_config.environments, var.environment, "Error: Invalid Environment!")
  }
  common_tags = {
    Environment = var.environment
    Managed-By  = "tf"  
  }
}

variable "environment" {
  type = string
  description = "Name of the environment"
  default = null
}

variable "config_file" {
  default = null
}

provider "aws" {
  region = local.config.environment.region
}

variable "subnet_id" {
  type = string
  default = null
}

variable "instance_name" {}
variable "ami_id" {}
variable "instance_type" {}
variable "key_name" {}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "associate_public_ip_address" {
  type = bool
  default = false
}

variable "volume_size" {
  type = string
  default = "8"
}

variable "cost_center" {}
variable "wait_for_instance_in_seconds" {
  default = "120s"
}
variable "wait_for_ssh" {
  default = false
}

variable "ec2_profile_name" {
  default = "ec2-core-profile"
}

data "aws_iam_instance_profile" "ec2-core-profile" {
  name = var.ec2_profile_name
}

data "aws_ssm_document" "cloud-init-wait" {
  name = "cloud-init-wait"
}

resource "aws_instance" "my_instance" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = var.vpc_security_group_ids
  associate_public_ip_address = var.associate_public_ip_address
  subnet_id                   = var.subnet_id
  iam_instance_profile        = data.aws_iam_instance_profile.ec2-core-profile.name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.volume_size
    delete_on_termination = true
  }

  provisioner "local-exec" {
    # SSM based dynamic wait for the new instance cloud-init to complete
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOF
    set -Ee -o pipefail
    export AWS_DEFAULT_REGION=${local.config.environment.region}
    sleep 30 
    command_id=$(aws ssm send-command --document-name ${data.aws_ssm_document.cloud-init-wait.arn} --instance-ids ${self.id} --output text --query "Command.CommandId")
    if ! aws ssm wait command-executed --command-id $command_id --instance-id ${self.id}; then
      echo "Failed to start services on instance ${self.id}!";
      echo "stdout:";
      aws ssm get-command-invocation --command-id $command_id --instance-id ${self.id} --query StandardOutputContent;
      echo "stderr:";
      aws ssm get-command-invocation --command-id $command_id --instance-id ${self.id} --query StandardErrorContent;
      exit 1;
    fi;
    echo "Services started successfully on the new instance with id ${self.id}!"
    EOF
  }

  tags = merge (
    {
      Name = var.instance_name
      AMI-ID = var.ami_id
      Cost-Center = var.cost_center
    },
    local.common_tags
  )

}

output "host_private_ip" {
  value = "${aws_instance.my_instance.private_ip}"
}

resource "time_sleep" "wait_for" {
  count = var.wait_for_ssh ? 1 : 0
  create_duration = var.wait_for_instance_in_seconds
}

resource "null_resource" "wait_for_ssh_connection" {
  count = var.wait_for_ssh ? 1 : 0

  depends_on    = [aws_instance.my_instance, time_sleep.wait_for]

  # allows to run this playbook during each apply.
  triggers = {
    always_run = timestamp()
  }

  # Helps to wait fot the new instance to launch and accept ssh connection for playbook execution
  # When SSM run-command is configued, this hard-coded wait is not required. We can disable for SSM dynamic wait for cloud-init to complete.
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      host = "${aws_instance.my_instance.private_ip}"
      bastion_host = local.config.environment.bastion_host_name
      bastion_user = local.config.environment.bastion_host_user
      bastion_private_key = file(local.config.environment.bastion_host_private_key_file_path)
      bastion_port = 22
      user = local.config.environment.ami_user
    }
    inline = [
      "echo 'Connected! to the new instance.'"
    ]
  }

}