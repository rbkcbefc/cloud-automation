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
  default = "my-ubuntu-containerd"
}

variable "centos_ami_prefix" {
  type    = string
  default = "my-centos-containerd"
}

variable "al2023_ami_prefix" {
  type    = string
  default = "my-al2023-containerd"
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
    Name = "my-ubuntu-containerd"
  }
}

source "amazon-ebs" "centos-stream-9" {
  ami_name      = "${var.centos_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    =  "${var.my_centos_base_ami}"
  ssh_username  = "ec2-user"
  tags = {
    Name = "my-centos-containerd"
  }
}

source "amazon-ebs" "al2023" {
  ami_name      = "${var.al2023_ami_prefix}-${local.timestamp}"
  instance_type = "t4g.nano"
  region        = "us-east-1"
  source_ami    =  "${var.my_al2023_base_ami}"
  ssh_username  = "ec2-user"
  tags = {
    Name = "my-al2023-containerd"
  }
}

build {
  name = "my-containerd-ami"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "ansible" {
    playbook_file = "playbooks/setup-containerd.yml" 
    extra_arguments = [ 
      "-vv" 
    ]
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False"
    ]
  }
}
