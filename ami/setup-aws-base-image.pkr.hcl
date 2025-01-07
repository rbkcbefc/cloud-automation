# Purpose: This image is used to launch plain vannila EC2 instances (Bastion Host etc) and 
# serves as base image for other images ( Docker, ECS & Self Hosted Actions Runner etc)

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
  default = "my-ubuntu-base"
}

variable "centos_ami_prefix" {
  type    = string
  default = "my-centos-base"
}

variable "al2023_ami_prefix" {
  type    = string
  default = "my-al2023-base"
}

variable "ubuntu_source_ami" {
  type    = string
  default = "ami-096ea6a12ea24a797"
}

variable "centos_source_ami" {
  type    = string
  default = "ami-01c7f43e443d5117d"
}

variable "al2023_source_ami" {
  type    = string
  default = "ami-02dcfe5d1d39baa4e"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "${var.ubuntu_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    = "${var.ubuntu_source_ami}"
  ssh_username = "ubuntu"
  tags = {
    Name = "my-ubuntu-base"
  }
}

source "amazon-ebs" "centos-stream-9" {
  ami_name      = "${var.centos_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    = "${var.centos_source_ami}"
  ssh_username = "ec2-user"
  tags = {
    Name = "my-centos-base"
  }
}

source "amazon-ebs" "al2023" {
  ami_name      = "${var.al2023_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    = "${var.al2023_source_ami}"
  ssh_username = "ec2-user"
  tags = {
    Name = "my-al2023-base"
  }
}

build {
  name = "my-base-ami"
  sources = [
    "source.amazon-ebs.al2023",
    "source.amazon-ebs.ubuntu",
    "source.amazon-ebs.centos-stream-9"
  ]

  provisioner "ansible" {
    playbook_file = "playbooks/setup-base-image.yml" 
  }
}
