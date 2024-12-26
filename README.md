# cloud-automation
Cloud Automation using Vagrant, Ansible, Packer &amp; Terraform DevOps Tools

# Prerequisite
This project's Vagrantfile is configured to develop using Mac Book Pro M3 Chip ( AMD64 ).

In case you have Intel chip, update the Vagrantfile to launch VM ( centos / ubuntu) of AMD64 architecture.


# Bring-up Vagrant VM

Copy Vagrantfile_centos (or) Vagrantfile_ubuntu as Vagrantfile to develop Ansible Playbook / Role.

vagrant up

This will bring-up the VM ( cacentos / caubuntu ) 

Checkout the Vagrantfile's provision block. It is configured to run Ansible Playbook: setup-base-image.yml

Note: In case, ubuntu vm failed to provision w/ error message like: Could not get lock 

vagrant reload caubuntu
vagrant provision caubuntu

Above two steps should provision the Ubuntu VM successfully.

To shell into the VM, 
vagrant ssh

# TF - Provider 

# TF - VPC

# Packer Images 

# Create New Ansible Role
make create_role role=my-role

This will create a new directory 'my-role' under 'roles' w/ bunch of sub-directories. 

# Next: TF - One Instance - Jenkins (Ansible Role) - TF use packer ami & provisioner call playbook

# Install Docker in base image

# Packer 
create file: variables.auto.pkrvars.hcl and pass values for variables in build files.
Base AMI:
packer build ami/setup-aws-base-image.pkr.hcl

Eg:
cd cloud_automation
packer build -var-file=ami/variables.auto.pkrvars.hcl  ami/setup-aws-docker-image.pkr.hcl

# Pre EC2 launch instance
create ec2-core role & profile

# SSH into Bastion Host
ssh-add -K /Users/bala/.ssh/rbkbusde-us-east-1.pem
ssh -A ubuntu@3.85.233.62
ssh -J ubuntu@3.85.233.62 ubuntu@10.0.1.245

# Supported Operating Systems
Ubuntu, Amazon Linux 2023 & CentOS Streams 9

# Supported CPU architecture
ARM64 & AMD64

# Ansible Debug
export ANSIBLE_DEBUG=1
