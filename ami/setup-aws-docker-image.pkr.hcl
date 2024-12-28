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
  default = "my-ubuntu-docker"
}

variable "centos_ami_prefix" {
  type    = string
  default = "my-centos-docker"
}

variable "al2023_ami_prefix" {
  type    = string
  default = "my-al2023-docker"
}

variable "my_ubuntu_base_ami" {
  type    = string
  default = ""
}

variable "my_centos_base_ami" {
  type    = string
  default = ""
}

variable "my_al2023_base_ami" {
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
  source_ami    = "${var.my_ubuntu_base_ami}"
  ssh_username = "ubuntu"
  tags = {
    Name = "my-ubuntu-docker"
  }
}

source "amazon-ebs" "centos-stream-9" {
  ami_name      = "${var.centos_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    =  "${var.my_centos_base_ami}"
  ssh_username  = "ec2-user"
  tags = {
    Name = "my-centos-docker"
  }
}

source "amazon-ebs" "al2023" {
  ami_name      = "${var.al2023_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    =  "${var.my_al2023_base_ami}"
  ssh_username  = "ec2-user"
  tags = {
    Name = "my-al2023-docker"
  }
}

build {
  name = "my-docker-ami"
  sources = [
    "source.amazon-ebs.al2023",
    "source.amazon-ebs.ubuntu",
    "source.amazon-ebs.centos-stream-9"
  ]

  provisioner "ansible" {
    playbook_file = "playbooks/setup-docker.yml" 
  }
}
