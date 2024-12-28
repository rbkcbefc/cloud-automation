packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = "~> 1.1"
      source = "github.com/hashicorp/ansible"
    }
    vagrant = {
      version = ">= 1.1.1"
      source = "github.com/hashicorp/vagrant"
    }
  }
}

variable "ubuntu_ami_prefix" {
  type    = string
  default = "my-ubuntu-ecs-agent"
}

variable "centos_ami_prefix" {
  type    = string
  default = "my-centos-ecs-agent"
}

variable "my_ubuntu_ecr_helper_ami" {
  type    = string
  default = ""
}

variable "my_centos_ecr_helper_ami" {
  type    = string
  default = ""
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "${var.ubuntu_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    = "${var.my_ubuntu_ecr_helper_ami}"
  ssh_username = "ubuntu"
  tags = {
    Name = "my-ubuntu-aws-ecs-agent"
  }
}

source "amazon-ebs" "centos-stream-9" {
  ami_name      = "${var.centos_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    =  "${var.my_centos_ecr_helper_ami}"
  ssh_username  = "ec2-user"
  tags = {
    Name = "my-centos-aws-ecs-agent"
  }
}

build {
  name = "my-ecs-ami"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "ansible" {
    extra_arguments = [ "-v" ]
    playbook_file = "playbooks/setup-aws-ecs-agent.yml" 
  }

  post-processor "manifest" {
    output = "manifest.json"
    strip_path = true
  }

}
