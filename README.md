# About - Cloud Automation

This framework integrates Vagrant, Ansible, Packer &amp; Terraform Infrastructure As Code (IaC) DevOps Tools to implement CI/CD using Github Actions in AWS Elastic Container Service ( ECS - Container Orchestration in Bridge Mode ) Platform.

To demonstrate the features, two simple Java based Microservices are built & deployed on AWS ECS.

- Mock Email Service ( https://github.com/rbkcbefc/mock-email-service )
- Mock Nasa Sound API Service ( https://github.com/rbkcbefc/mock-nasa-sound-api-service )

- Operating Systems: Ubuntu, Amazon Linux 2023 & CentOS Streams 9
- CPU Architectures: ARM64 & AMD64
- Supports provisioning multiple Environments ( Nightly, QA, Staging, Production etc ) based on reusable Terraform modules
- Supports Bastion Host for Network Security
- Integrates Terraform ( local-exec mode ) & Ansible for provision-time configuration by running Playbook through Bastion Host.
- Integrates Elastic Container Registry ( ECR ) to store Container Images
- Integrates Ansible AWS Dynamic Inventory Plugin
- Integrates Ansible Secrets 
- Integrates Jinja Templates in Terraform & Ansible
- Integrates Route53 ( Domain: agilealm.click )
- Integrates HTTPS/SSL using Amazon Certificate Manager ( ACM )

# Technologies

- Vagrant ( https://www.vagrantup.com/ ) - Vagrant enables the creation and configuration of lightweight, reproducible, and portable development environments.
- Ansible ( https://docs.ansible.com/ ) - Ansible lets you automate virtually any IT task ( Manage and maintain system configuration ).
- Packer ( https://www.packer.io/ ) - Automate image builds with Packer
- Terraform ( https://www.terraform.io/ ) - Infrastructure automation to provision and manage resources in any cloud or data center.

# Methodology

- Develop Ansible Roles & Playbooks using Vagrant based Virtual Machines running on developers Laptops.
- Build Virtual Machine to run on Cloud Providers / Hyperscalers (like AWS, GCP & Azure ) using Packer and Ansible ( locally tested Roles and Playbooks )
- Provision Infrastructure ( Cloud Resources like AWS VPC, EC2 Instances, ALB, S3 Bucket etc ) using Terraform
- Configuration Management using Ansible

# Getting Started

- This project's Vagrantfile is configured to develop using Mac Book Pro M3 Chip ( ARM64 ).
In case you have Intel chip (AMD64), update the Vagrantfile to launch VM ( centos / ubuntu) of AMD64 architecture.
- Setup an account in AWS and configure AWS CLI
- Install Ansible, Vagrant, Packer & Terraform

# Configuration Management ( Ansible )

- Checkout the two directories ( roles & playbooks ) for setting-up Golden Image ( all basic utilities ) , Docker, Github Self-hosting Actions Runner, AWS ECS Agent + ECR Helper etc.

# Development Environment ( Vagrant Virtual Machine )

- This step helps to verify your Ansible Playbooks (one or more roles) in your development environment (laptop)
- Choose your OS (Ubuntu or CentOS / AL 2023). Copy Vagrantfile_centos (or) Vagrantfile_ubuntu as Vagrantfile
- Configure your Vagrantfile "provision" section to run desired Ansible Playbook ( setup-base-image.yml / setup-docker.yml / setup-actions-runner.yml / setup-aws-ecr-ecs.yml d)

# Build Virtual Machine Image ( Packer )

- This step helps to build AMIs ( Amazon Machine Image ) to launch EC2 instances.
- To configure, create file: variables.auto.pkrvars.hcl and pass values for variables declared in file: variables.pkrvars.hcl
- Build Base AMI:
cd cloud_automation
packer build ami/setup-aws-base-image.pkr.hcl
- Build Docker AMI:
cd cloud_automation
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-docker-image.pkr.hcl
- Build ECS AMI
cd cloud_automation
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-ecr-ecs.pkr.hcl

# Provision AWS Infrastructure ( Terraform )

- This step helps to provision infrastructure on the AWS Cloud
- Configure Terraform Remote State Management ( Dynamo DB )
cd cloud-automation
terraform -chdir=envs/aws/infra/provider/nightly init <config_file>, plan & apply
- Provision AWS VPC
terraform -chdir=envs/aws/infra/vpc init <config_file>, plan & apply
- Provision Security Groups ( bastion host, ecs, alb and internal access )
terraform -chdir=envs/aws/infra/security-group/nightly/bastion-host init <config_file>, plan & apply
- Provision iam-policy & iam-role
- Provision ssm-document ( cloud-init-wait )
- Update config: aws-config.yml 
- Provision bastion-host
- Provision ECR repos ( Mock Email Service & Mock Nasa Sound API Service )
- Provision ECS ( Launch Template, ALB, ASG, ALB, Target Group & Cluster )
- Provision Github Actions Self-hosted Runners ( Mock Email Service & Mock Nasa Sound API Service)
- Trigger Github Action Builds  ( Mock Email Service & Mock Nasa Sound API Service) 
- Provision ECS Services ( Mock Email Service & Mock Nasa Sound API Service) 
- Provision Route53 ( Hosted Zone, ACM & CNAME ) - https://mockemailservice.agilealm.click/mockemailservice/index.jsp

# Continous Integration & Delivery ( Github Actions )

- Check the workflow: https://github.com/rbkcbefc/mock-nasa-sound-api-service/blob/master/.github/workflows/build-self-runner-arm64.yml
Using Self-hosted Runner, Build Docker Image, Push to ECR and Deploy to ECS

# SSH into Target Host Via Bastion Host
ssh-add -K /Users/<user_name>/.ssh/<aws_key_file>.pem
ssh -A <user>@<bastion_host_ip>
ssh -J <user>@<bastion_host_ip> <user>@<target_host_ip>

# Ansible Debug
export ANSIBLE_DEBUG=1
config file: ansible.cfg

