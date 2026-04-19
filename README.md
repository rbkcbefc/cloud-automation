# Cloud Automation Framework

A comprehensive Infrastructure as Code (IaC) framework that integrates **Vagrant**, **Ansible**, **Packer**, and **Terraform** to automate cloud infrastructure deployment on AWS. This project demonstrates modern DevOps practices with CI/CD using GitHub Actions, deploying containerized microservices on AWS ECS and self-hosted Kubernetes clusters.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Technologies](#technologies)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Documentation](#documentation)
- [Example Microservices](#example-microservices)
- [Debugging](#debugging)
- [Contributing](#contributing)

## Overview

This framework provides a complete DevOps automation solution for AWS cloud infrastructure, featuring:

- **Multi-environment support**: Nightly, QA, Staging, and Production
- **Container orchestration**: AWS ECS (Bridge Mode) and Kubernetes (kubeadm)
- **CI/CD automation**: GitHub Actions with self-hosted runners
- **Infrastructure as Code**: Terraform modules and Ansible roles
- **Secure networking**: Bastion host architecture for enhanced security
- **Multi-platform**: Ubuntu, Amazon Linux 2023, and CentOS Stream 9
- **Multi-architecture**: ARM64 and AMD64 support

## Features

### Core Capabilities

- **Self-Hosted GitHub Actions Runners** - Build and deploy Java applications directly to AWS ECS
- **Multi-Environment Provisioning** - Reusable Terraform modules for Nightly, QA, Staging, and Production
- **Bastion Host Security** - Secure access to internal infrastructure via jump host
- **Terraform + Ansible Integration** - Provision-time configuration using local-exec provisioner
- **AWS ECR Integration** - Private container registry for Docker images
- **Dynamic Inventory** - Ansible AWS EC2 dynamic inventory plugin
- **Secrets Management** - Ansible Vault for encrypted credentials
- **Template Support** - Jinja2 templates in both Terraform and Ansible
- **DNS & SSL** - Route53 integration with ACM certificates (domain: agilealm.click)
- **Kubernetes Support** - Self-hosted kubeadm cluster (1 control plane + 2 data plane nodes) with Containerd and Calico

### Platform Support

| Component | Options |
|-----------|---------|
| **Operating Systems** | Ubuntu, Amazon Linux 2023, CentOS Stream 9 |
| **CPU Architectures** | ARM64, AMD64 |
| **Container Runtimes** | Docker, Containerd |
| **Orchestration** | AWS ECS (Bridge Mode), Kubernetes (kubeadm) |

## Architecture

This project follows a layered architecture approach:

1. **Development Layer** - Vagrant VMs for local development and testing
2. **Image Layer** - Packer for building golden AMIs with pre-configured software
3. **Infrastructure Layer** - Terraform for provisioning AWS resources
4. **Configuration Layer** - Ansible for runtime configuration management
5. **Application Layer** - Containerized microservices deployed via CI/CD

For detailed architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Technologies

| Tool | Version | Purpose |
|------|---------|---------|
| [Vagrant](https://www.vagrantup.com/) | Latest | Local development environments |
| [Ansible](https://docs.ansible.com/) | Latest | Configuration management and automation |
| [Packer](https://www.packer.io/) | Latest | Automated AMI builds |
| [Terraform](https://www.terraform.io/) | Latest | Infrastructure provisioning |
| [Docker](https://www.docker.com/) | CE | Container runtime |
| [Containerd](https://containerd.io/) | Latest | Container runtime for Kubernetes |

## Prerequisites

### Required Tools

Install the following tools on your local machine:

```bash
# macOS (using Homebrew)
brew install vagrant
brew install ansible
brew install packer
brew install terraform
brew install awscli

# Verify installations
vagrant --version
ansible --version
packer --version
terraform --version
aws --version
```

### AWS Account Setup

1. Create an AWS account at [aws.amazon.com](https://aws.amazon.com)
2. Configure AWS CLI with your credentials:
   ```bash
   aws configure
   ```
3. Ensure you have appropriate IAM permissions for:
   - EC2 (instances, AMIs, security groups)
   - VPC (networking, subnets, route tables)
   - ECS (clusters, services, task definitions)
   - ECR (repositories)
   - IAM (roles, policies)
   - Route53 (hosted zones, records)
   - ACM (certificates)
   - S3 (Terraform state)
   - DynamoDB (Terraform state locking)

### Hardware Requirements

- **For ARM64 (Apple Silicon)**: MacBook Pro M1/M2/M3 or later
- **For AMD64 (Intel)**: Any Intel-based system
- At least 8GB RAM for local Vagrant VMs
- 20GB free disk space

**Note**: The Vagrantfile is pre-configured for ARM64 (Apple Silicon). For Intel systems, update the Vagrantfile to use AMD64 base boxes.

## Quick Start

### 1. Development Environment (Vagrant)

Test Ansible playbooks locally before deploying to AWS:

```bash
# Choose your OS and copy the appropriate Vagrantfile
cp Vagrantfile_ubuntu Vagrantfile
# OR
cp Vagrantfile_centos Vagrantfile

# Start the VM
vagrant up

# SSH into the VM
vagrant ssh

# Destroy when done
vagrant destroy
```

### 2. Build AMIs (Packer)

Create golden AMIs for AWS EC2 instances:

```bash
# Create Packer variables file
cp ami/variables.pkrvars.hcl ami/variables.auto.pkrvars.hcl
# Edit ami/variables.auto.pkrvars.hcl with your AWS settings

# Build base AMI
packer build ami/setup-aws-base-image.pkr.hcl

# Build Docker AMI
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-docker-image.pkr.hcl

# Build ECS AMI
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-ecr-ecs-image.pkr.hcl
```

### 3. Provision Infrastructure (Terraform)

Deploy AWS infrastructure:

```bash
# 1. Initialize Terraform state backend
terraform -chdir=envs/aws/infra/provider/nightly init -backend-config=envs/aws/backend-s3-nightly.conf
terraform -chdir=envs/aws/infra/provider/nightly plan
terraform -chdir=envs/aws/infra/provider/nightly apply

# 2. Create VPC
terraform -chdir=envs/aws/infra/vpc/nightly init -backend-config=../../backend-s3-nightly.conf
terraform -chdir=envs/aws/infra/vpc/nightly apply

# 3. Create Security Groups
terraform -chdir=envs/aws/infra/security-group/nightly/bastion-host init -backend-config=../../../backend-s3-nightly.conf
terraform -chdir=envs/aws/infra/security-group/nightly/bastion-host apply

# Continue with other components...
```

For complete deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Project Structure

```
cloud-automation/
├── ami/                    # Packer configurations for building AMIs
│   ├── setup-aws-base-image.pkr.hcl
│   ├── setup-aws-docker-image.pkr.hcl
│   ├── setup-aws-ecr-ecs-image.pkr.hcl
│   ├── setup-aws-containerd-image.pkr.hcl
│   └── variables.pkrvars.hcl
├── roles/                  # Ansible roles (8 roles)
│   ├── basic_utils/       # Common utilities installation
│   ├── docker/            # Docker CE setup
│   ├── containerd/        # Containerd runtime
│   ├── ecr-helper/        # ECR credential helper
│   ├── ecs-agent/         # ECS agent installation
│   ├── aws-ssm-agent/     # SSM Session Manager
│   ├── setup-actions-runner/  # GitHub Actions runner
│   └── k8s-kubeadm-sh/    # Kubernetes kubeadm setup
├── playbooks/             # Ansible playbooks (10 playbooks)
│   ├── setup-base-image.yml
│   ├── setup-docker.yml
│   ├── setup-aws-ecr-ecs.yml
│   └── setup-k8s-kubeadm-sh.yml
├── modules/               # Terraform reusable modules
│   └── aws/infra/
│       ├── vpc/
│       ├── security-group/
│       ├── ec2-instance/
│       ├── ecs/
│       ├── alb/
│       └── route53/
├── envs/                  # Environment-specific configurations
│   └── aws/
│       ├── aws-config.yml        # Central configuration
│       ├── infra/                # Infrastructure definitions
│       │   ├── provider/
│       │   ├── vpc/
│       │   ├── security-group/
│       │   ├── ec2-instances/
│       │   ├── ecs/
│       │   ├── ecr/
│       │   ├── iam-role/
│       │   ├── route53/
│       │   └── k8s/
│       └── app/                  # Application deployments
│           ├── mock-email-service/
│           └── mock-nasa-sound-api-service/
├── Makefile               # Build automation helpers
├── ansible.cfg            # Ansible configuration
├── hosts.aws_ec2.yml      # AWS EC2 dynamic inventory
├── Vagrantfile_ubuntu     # Ubuntu development VM
└── Vagrantfile_centos     # CentOS development VM
```

## Documentation

Detailed documentation is available in the following files:

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design patterns
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete step-by-step deployment guide
- **[docs/ANSIBLE.md](docs/ANSIBLE.md)** - Ansible roles and playbooks reference
- **[docs/TERRAFORM.md](docs/TERRAFORM.md)** - Terraform modules documentation
- **[docs/PACKER.md](docs/PACKER.md)** - AMI building guide
- **[docs/KUBERNETES.md](docs/KUBERNETES.md)** - Kubernetes setup and operations

## Example Microservices

This project deploys two sample Java microservices to demonstrate the framework:

1. **[Mock Email Service](https://github.com/rbkcbefc/mock-email-service)**
   - Simple email service simulation
   - Deployed at: https://mockemailservice.agilealm.click/mockemailservice/index.jsp

2. **[Mock NASA Sound API Service](https://github.com/rbkcbefc/mock-nasa-sound-api-service)**
   - NASA sound API simulation
   - CI/CD workflow: [build-self-runner-arm64.yml](https://github.com/rbkcbefc/mock-nasa-sound-api-service/blob/master/.github/workflows/build-self-runner-arm64.yml)

Both services are:
- Built using GitHub Actions self-hosted runners
- Containerized and pushed to ECR
- Deployed to AWS ECS with automatic rollout

## SSH Access via Bastion Host

Access internal infrastructure securely through the bastion host:

```bash
# Add your SSH key to the agent
ssh-add -K /Users/<username>/.ssh/<aws_key_file>.pem

# SSH to bastion host
ssh -A <user>@<bastion_host_ip>

# SSH to target host via bastion (jump host)
ssh -J <user>@<bastion_host_ip> <user>@<target_host_ip>
```

## Debugging

### Vagrant Debugging

```bash
# Enable verbose logging
export VAGRANT_LOG=info
vagrant up --debug &> vagrant.log

# View the log
tail -f vagrant.log
```

**Resources**:
- [Vagrant Debugging Guide](https://developer.hashicorp.com/vagrant/docs/other/debugging)
- [Vagrant Ansible Provisioning](https://developer.hashicorp.com/vagrant/docs/provisioning/ansible_intro)

### Ansible Debugging

```bash
# Enable debug mode
export ANSIBLE_DEBUG=true
export ANSIBLE_VERBOSITY=2  # Use 3 or 4 for more verbosity

# Run playbook with verbose output
ansible-playbook -vvv playbooks/setup-base-image.yml
```

Configuration file: `ansible.cfg`

### Terraform Debugging

```bash
# Enable debug logging
export TF_LOG=debug
export TF_LOG_PATH=terraform-debug.log

# Run Terraform commands
terraform plan
terraform apply

# View logs
tail -f terraform-debug.log
```

### Packer Debugging

```bash
# Enable Packer logging
export PACKER_LOG=1
export PACKER_LOG_PATH=packer-debug.log

# Build with debug output
packer build -debug ami/setup-aws-base-image.pkr.hcl
```

### Kubernetes Troubleshooting

```bash
# Using crictl for container inspection
crictl ps
crictl logs <container-id>
crictl inspect <container-id>
```

**Resources**:
- [crictl - Kubernetes CLI Tool](https://www.virtualizationhowto.com/2024/12/crictl-kubernetes-command-line-tool-for-troubleshooting/)

## Kubernetes (k8s-kubeadm-sh)

This project includes a self-hosted Kubernetes environment using **kubeadm** with **Containerd** runtime and **Calico** networking.

### Architecture

**Components**:
- **1 Control Plane Node** - Manages the cluster (public subnet, API server on port 6443)
- **2 Data Plane Nodes** - Worker nodes (private subnet, accessible via bastion host)

**Implementation**:

**Ansible Roles**:
- `roles/containerd` - Installs and configures containerd runtime
- `roles/k8s-kubeadm-sh` - Sets up Kubernetes cluster with kubeadm

**Terraform Modules**:
- `envs/aws/infra/k8s/kubeadm-sh/cp-node` - Control plane node
- `envs/aws/infra/k8s/kubeadm-sh/dp-node-1` - Data plane node 1
- `envs/aws/infra/k8s/kubeadm-sh/dp-node-2` - Data plane node 2

**Network Design**:
- Control plane in public subnet (API server accessible on port 6443)
- Data plane nodes in private subnet (accessed via bastion host)
- Calico CNI for pod networking

**Secrets Management**:
- Join tokens and discovery tokens stored in `ansible-vault`
- Generated during control plane provisioning
- Used for joining data plane nodes to the cluster

**Application Deployment**:
Kubernetes manifests are located in:
```
envs/aws/app/mock-email-service/k8s-kubeadm-sh/
├── namespace.yaml
├── deployment.yaml
└── service.yaml
```

**Accessing Services**:
```bash
# Get service information
kubectl get service -n mock-service

# The mock-email-service is accessible via LoadBalancer IP
kubectl get svc -n mock-service
```

For detailed Kubernetes setup instructions, see [docs/KUBERNETES.md](docs/KUBERNETES.md).

## Makefile Commands

The project includes a Makefile with helpful commands:

```bash
# Install Terraform helper for Apple Silicon
make install-tf-helper

# Create new Ansible role
make create-role ROLE_NAME=<name>

# Create new Terraform module
make create-module MODULE_NAME=<name>

# View all available commands
make help
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test your changes locally using Vagrant
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

This project is provided as-is for educational and demonstration purposes.

## Acknowledgments

- HashiCorp for Vagrant, Packer, and Terraform
- Red Hat for Ansible
- Amazon Web Services for cloud infrastructure
- The Kubernetes community

---

- Chao
