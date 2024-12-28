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
  default = "my-ubuntu-ecr-ecs"
}

variable "centos_ami_prefix" {
  type    = string
  default = "my-centos-ecr-ecs"
}

variable "al2023_ami_prefix" {
  type    = string
  default = "my-al2023-ecr-ecs"
}

variable "my_ubuntu_docker_ami" {
  type    = string
  default = ""
}

variable "my_centos_docker_ami" {
  type    = string
  default = ""
}

variable "my_al2023_docker_ami" {
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
  source_ami    = "${var.my_ubuntu_docker_ami}"
  ssh_username = "ubuntu"
  tags = {
    Name = "my-ubuntu-aws-ecr-ecs"
  }
}

source "amazon-ebs" "centos-stream-9" {
  ami_name      = "${var.centos_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    =  "${var.my_centos_docker_ami}"
  ssh_username  = "ec2-user"
  tags = {
    Name = "my-centos-aws-ecr-ecs"
  }
}

source "amazon-ebs" "al2023" {
  ami_name      = "${var.al2023_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    = "${var.my_al2023_docker_ami}"
  ssh_username = "ec2-user"
  tags = {
    Name = "my-al2023-aws-ecr-ecs"
  }
}


build {
  name = "my-ecs-ami"
  sources = [
    "source.amazon-ebs.al2023",
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "ansible" {
    extra_arguments = [ "-v" ]
    playbook_file = "playbooks/setup-aws-ecr-ecs.yml"
  }

}
