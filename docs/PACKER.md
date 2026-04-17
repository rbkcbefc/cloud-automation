# Packer Documentation

This document provides comprehensive documentation for building Amazon Machine Images (AMIs) using Packer and Ansible.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [AMI Hierarchy](#ami-hierarchy)
- [Packer Templates](#packer-templates)
- [Variables Configuration](#variables-configuration)
- [Build Process](#build-process)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

Packer automates the creation of machine images (AMIs) for AWS EC2. This project uses Packer to build golden AMIs with pre-configured software, reducing instance launch time and ensuring consistency.

**Key Benefits**:
- **Immutable Infrastructure**: Pre-baked AMIs reduce configuration drift
- **Faster Deployments**: Software pre-installed in AMI
- **Consistency**: Same base image across all environments
- **Version Control**: AMI builds are code-versioned

**Integration**:
- **Provisioner**: Ansible playbooks for software installation
- **Base Images**: Official Ubuntu, CentOS, or Amazon Linux AMIs
- **Output**: Registered AMIs ready for EC2 launch

## Prerequisites

### Required Tools

```bash
# Install Packer
brew install packer

# Verify installation
packer version  # Should be >= 1.9.0

# Verify Ansible is installed
ansible --version  # Required for provisioning
```

### AWS Configuration

```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity

# Ensure IAM user has permissions:
# - EC2: DescribeImages, CreateImage, RunInstances, TerminateInstances
# - EC2: CreateTags, DescribeInstances, DescribeSnapshots
```

### Directory Structure

```
cloud-automation/
├── ami/
│   ├── setup-aws-base-image.pkr.hcl
│   ├── setup-aws-docker-image.pkr.hcl
│   ├── setup-aws-containerd-image.pkr.hcl
│   ├── setup-aws-ecr-helper-image.pkr.hcl
│   ├── setup-aws-ecs-agent-image.pkr.hcl
│   ├── setup-aws-ecr-ecs-image.pkr.hcl
│   ├── variables.pkrvars.hcl            # Variable definitions
│   └── variables.auto.pkrvars.hcl       # Your values (gitignored)
└── playbooks/
    ├── setup-base-image.yml
    ├── setup-docker.yml
    ├── setup-containerd.yml
    ├── setup-aws-ecr-helper.yml
    ├── setup-aws-ecs-agent.yml
    └── setup-aws-ecr-ecs.yml
```

## AMI Hierarchy

AMIs are built in layers, with each layer adding functionality:

```
Official AWS AMI (Ubuntu/CentOS/AL2023)
           ↓
    ┌──────────────┐
    │  Base AMI    │  ← setup-aws-base-image.pkr.hcl
    │ (basic_utils)│     Playbook: setup-base-image.yml
    └──────────────┘
           ↓
      ┌────┴────┐
      ↓         ↓
┌──────────┐  ┌──────────────┐
│Docker AMI│  │Containerd AMI│
│          │  │              │
└──────────┘  └──────────────┘
      ↓              ↓
  ┌───┴───┐       ┌──────────────┐
  ↓       ↓       │ Kubernetes   │
┌────┐  ┌────┐   │  Node AMI    │
│ECR │  │ECS │   └──────────────┘
│    │  │    │
└────┘  └────┘
  ↓       ↓
  └───┬───┘
      ↓
┌─────────────┐
│ ECR-ECS AMI │
│ (combined)  │
└─────────────┘
```

**Build Order**:
1. Base AMI
2. Docker AMI (from Base) OR Containerd AMI (from Base)
3. ECR Helper AMI (from Docker) AND ECS Agent AMI (from Docker)
4. ECR-ECS Combined AMI (from Docker)

## Packer Templates

### 1. setup-aws-base-image.pkr.hcl

**Purpose**: Create base AMI with common utilities

**Location**: `ami/setup-aws-base-image.pkr.hcl`

**Playbook Used**: `playbooks/setup-base-image.yml`

**Software Installed**:
- git, curl, wget
- vim, nano
- htop, net-tools
- jq, unzip, zip
- OS-specific utilities

**Template Structure**:
```hcl
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1.0"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t4g.nano"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

source "amazon-ebs" "ubuntu_arm64" {
  ami_name      = "base-ubuntu-arm64-{{timestamp}}"
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-*-*-arm64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]  # Canonical
  }
  ssh_username = var.ssh_username
  tags = {
    Name        = "base-ubuntu-arm64"
    OS          = "Ubuntu"
    Arch        = "ARM64"
    BuildDate   = "{{timestamp}}"
    ManagedBy   = "Packer"
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu_arm64"]

  provisioner "ansible" {
    playbook_file = "${path.root}/../playbooks/setup-base-image.yml"
    user          = var.ssh_username
  }

  post-processor "manifest" {
    output = "manifest-base.json"
  }
}
```

**Building**:
```bash
# Validate template
packer validate ami/setup-aws-base-image.pkr.hcl

# Build
packer build ami/setup-aws-base-image.pkr.hcl

# Output example:
# ==> Builds finished. The artifacts of successful builds are:
# --> amazon-ebs.ubuntu_arm64: AMIs were created:
# us-east-1: ami-0123456789abcdef0
```

---

### 2. setup-aws-docker-image.pkr.hcl

**Purpose**: Create Docker-ready AMI

**Location**: `ami/setup-aws-docker-image.pkr.hcl`

**Playbook Used**: `playbooks/setup-docker.yml`

**Software Installed**:
- Docker CE
- Docker daemon configuration (overlay2 storage driver)
- Docker service enabled

**Variables Required**:
```hcl
variable "base_ami_id" {
  type        = string
  description = "Base AMI ID to build upon"
}
```

**Template**:
```hcl
source "amazon-ebs" "docker_ubuntu_arm64" {
  ami_name      = "docker-ubuntu-arm64-{{timestamp}}"
  instance_type = var.instance_type
  region        = var.aws_region
  source_ami    = var.base_ami_id
  ssh_username  = var.ssh_username
  tags = {
    Name      = "docker-ubuntu-arm64"
    OS        = "Ubuntu"
    Arch      = "ARM64"
    Software  = "Docker"
    BuildDate = "{{timestamp}}"
  }
}

build {
  sources = ["source.amazon-ebs.docker_ubuntu_arm64"]

  provisioner "ansible" {
    playbook_file = "${path.root}/../playbooks/setup-docker.yml"
    user          = var.ssh_username
  }
}
```

**Building**:
```bash
# Create variables file
cat > ami/variables.auto.pkrvars.hcl <<EOF
aws_region    = "us-east-1"
instance_type = "t4g.nano"
ssh_username  = "ubuntu"
base_ami_id   = "ami-0123456789abcdef0"  # From base AMI build
EOF

# Build
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-docker-image.pkr.hcl
```

---

### 3. setup-aws-containerd-image.pkr.hcl

**Purpose**: Create containerd runtime AMI for Kubernetes

**Location**: `ami/setup-aws-containerd-image.pkr.hcl`

**Playbook Used**: `playbooks/setup-containerd.yml`

**Software Installed**:
- containerd
- runc
- crictl
- CNI plugins

**Building**:
```bash
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-containerd-image.pkr.hcl
```

---

### 4. setup-aws-ecr-helper-image.pkr.hcl

**Purpose**: Create AMI with ECR credential helper

**Location**: `ami/setup-aws-ecr-helper-image.pkr.hcl`

**Playbook Used**: `playbooks/setup-aws-ecr-helper.yml`

**Software Installed**:
- amazon-ecr-credential-helper
- Docker config for ECR authentication

**Base AMI Required**: Docker AMI

**Variables**:
```hcl
variable "docker_ami_id" {
  type        = string
  description = "Docker AMI ID to build upon"
}
```

**Building**:
```bash
# Update variables
cat >> ami/variables.auto.pkrvars.hcl <<EOF
docker_ami_id = "ami-docker-xxxxx"  # From Docker AMI build
EOF

# Build
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-ecr-helper-image.pkr.hcl
```

---

### 5. setup-aws-ecs-agent-image.pkr.hcl

**Purpose**: Create AMI with ECS agent

**Location**: `ami/setup-aws-ecs-agent-image.pkr.hcl`

**Playbook Used**: `playbooks/setup-aws-ecs-agent.yml`

**Software Installed**:
- AWS ECS agent (as Docker container)
- Systemd service for ECS agent

**Base AMI Required**: Docker AMI

**Building**:
```bash
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-ecs-agent-image.pkr.hcl
```

---

### 6. setup-aws-ecr-ecs-image.pkr.hcl

**Purpose**: Create combined AMI with both ECR helper and ECS agent

**Location**: `ami/setup-aws-ecr-ecs-image.pkr.hcl`

**Playbook Used**: `playbooks/setup-aws-ecr-ecs.yml`

**Software Installed**:
- Docker CE
- amazon-ecr-credential-helper
- AWS ECS agent

**This is the recommended AMI for ECS deployments**

**Building**:
```bash
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-ecr-ecs-image.pkr.hcl
```

---

## Variables Configuration

### variables.pkrvars.hcl

Variable definitions (template):

```hcl
# AWS Configuration
variable "aws_region" {
  type        = string
  description = "AWS region to build AMI"
  default     = "us-east-1"
}

# Instance Configuration
variable "instance_type" {
  type        = string
  description = "EC2 instance type for Packer build"
  default     = "t4g.nano"  # ARM64
}

variable "ssh_username" {
  type        = string
  description = "SSH username for the AMI"
  default     = "ubuntu"
}

# Source AMI
variable "source_ami_owner" {
  type        = string
  description = "AWS account ID of AMI owner"
  default     = "099720109477"  # Canonical (Ubuntu)
}

variable "source_ami_name_filter" {
  type        = string
  description = "Name filter for source AMI"
  default     = "ubuntu/images/hvm-ssd/ubuntu-*-*-arm64-server-*"
}

# Custom AMI IDs (for layered builds)
variable "base_ami_id" {
  type        = string
  description = "Base AMI ID"
  default     = ""
}

variable "docker_ami_id" {
  type        = string
  description = "Docker AMI ID"
  default     = ""
}
```

### variables.auto.pkrvars.hcl

Your actual values (should be gitignored):

```hcl
# This file contains your actual values
aws_region    = "us-east-1"
instance_type = "t4g.nano"
ssh_username  = "ubuntu"

# Update these after each build
base_ami_id   = "ami-base-xxxxx"
docker_ami_id = "ami-docker-xxxxx"
```

---

## Build Process

### Complete Build Workflow

**Step 1: Build Base AMI**

```bash
# Validate
packer validate ami/setup-aws-base-image.pkr.hcl

# Build
packer build ami/setup-aws-base-image.pkr.hcl

# Capture AMI ID from output
# Example: ami-0a1b2c3d4e5f6g7h8
```

**Step 2: Update Variables**

```bash
# Edit variables.auto.pkrvars.hcl
vim ami/variables.auto.pkrvars.hcl

# Add:
# base_ami_id = "ami-0a1b2c3d4e5f6g7h8"
```

**Step 3: Build Docker AMI**

```bash
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-docker-image.pkr.hcl

# Capture Docker AMI ID
# Example: ami-docker123456789
```

**Step 4: Update Variables Again**

```bash
# Add to variables.auto.pkrvars.hcl:
# docker_ami_id = "ami-docker123456789"
```

**Step 5: Build ECS AMI**

```bash
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-ecr-ecs-image.pkr.hcl

# This is your final AMI for ECS deployments
```

**Step 6: Update aws-config.yml**

```bash
vim envs/aws/aws-config.yml

# Update:
# environments:
#   nightly:
#     ami_id_ecs: "ami-ecs-final-xxxxx"
```

---

### Build Script (Automated)

Create a build script for automation:

```bash
#!/bin/bash
# build-amis.sh

set -e

echo "Building Base AMI..."
BASE_AMI=$(packer build -machine-readable ami/setup-aws-base-image.pkr.hcl | \
  grep 'artifact,0,id' | cut -d, -f6 | cut -d: -f2)
echo "Base AMI: $BASE_AMI"

echo "Building Docker AMI..."
DOCKER_AMI=$(packer build -machine-readable \
  -var "base_ami_id=$BASE_AMI" \
  ami/setup-aws-docker-image.pkr.hcl | \
  grep 'artifact,0,id' | cut -d, -f6 | cut -d: -f2)
echo "Docker AMI: $DOCKER_AMI"

echo "Building ECS AMI..."
ECS_AMI=$(packer build -machine-readable \
  -var "docker_ami_id=$DOCKER_AMI" \
  ami/setup-aws-ecr-ecs-image.pkr.hcl | \
  grep 'artifact,0,id' | cut -d, -f6 | cut -d: -f2)
echo "ECS AMI: $ECS_AMI"

echo "All AMIs built successfully!"
echo "Base: $BASE_AMI"
echo "Docker: $DOCKER_AMI"
echo "ECS: $ECS_AMI"
```

Usage:
```bash
chmod +x build-amis.sh
./build-amis.sh
```

---

## Best Practices

### 1. Version Your AMIs

Use timestamps or semantic versioning:
```hcl
ami_name = "ecs-ubuntu-arm64-v1.2.3-{{timestamp}}"
```

### 2. Tag Your AMIs

Always add comprehensive tags:
```hcl
tags = {
  Name        = "ecs-ubuntu-arm64"
  Version     = "1.2.3"
  OS          = "Ubuntu"
  Arch        = "ARM64"
  Software    = "Docker,ECS"
  BuildDate   = "{{timestamp}}"
  ManagedBy   = "Packer"
  Environment = "Production"
  Team        = "DevOps"
}
```

### 3. Use Manifest Post-Processor

Track AMI IDs:
```hcl
post-processor "manifest" {
  output     = "manifest-ecs.json"
  strip_path = true
}
```

Output:
```json
{
  "builds": [
    {
      "name": "amazon-ebs.ecs_ubuntu_arm64",
      "builder_type": "amazon-ebs",
      "build_time": 1234567890,
      "artifact_id": "us-east-1:ami-0123456789abcdef0"
    }
  ]
}
```

### 4. Validate Before Building

Always validate templates:
```bash
packer validate ami/setup-aws-base-image.pkr.hcl
packer fmt ami/setup-aws-base-image.pkr.hcl
```

### 5. Use Variables Files

Keep configuration separate:
```bash
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-docker-image.pkr.hcl
```

### 6. Clean Up Old AMIs

Deregister unused AMIs:
```bash
# List AMIs
aws ec2 describe-images --owners self --query 'Images[*].[ImageId,Name,CreationDate]' --output table

# Deregister AMI
aws ec2 deregister-image --image-id ami-xxxxx

# Delete associated snapshots
aws ec2 describe-snapshots --owner-ids self --filters "Name=description,Values=*ami-xxxxx*"
aws ec2 delete-snapshot --snapshot-id snap-xxxxx
```

### 7. Test AMIs Before Use

Launch test instance:
```bash
aws ec2 run-instances \
  --image-id ami-xxxxx \
  --instance-type t4g.nano \
  --key-name cloud-automation-key \
  --subnet-id subnet-xxxxx \
  --security-group-ids sg-xxxxx

# SSH and verify
ssh ubuntu@<instance-ip>
docker --version
systemctl status ecs
```

---

## Troubleshooting

### Packer Build Failures

**Problem**: Timeout waiting for SSH

```bash
# Solution: Increase SSH timeout
source "amazon-ebs" "example" {
  # ...
  ssh_timeout = "10m"  # Default: 5m
}
```

**Problem**: Source AMI not found

```bash
# Verify AMI filter
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-arm64-server-*" \
  --query 'Images[*].[ImageId,Name,CreationDate]' \
  --output table

# Update filter in Packer template
```

### Ansible Provisioner Failures

**Problem**: Playbook task fails

```bash
# Enable Ansible debug mode
provisioner "ansible" {
  playbook_file = "../playbooks/setup-docker.yml"
  extra_arguments = ["-vvv"]  # Verbose mode
}
```

**Problem**: Cannot find playbook

```bash
# Use absolute path
provisioner "ansible" {
  playbook_file = "${path.root}/../playbooks/setup-docker.yml"
}
```

### AWS Permissions Issues

**Problem**: UnauthorizedOperation error

```bash
# Verify IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name <username>

# Attach required policies:
# - EC2FullAccess (or custom policy with EC2 permissions)
```

### Debug Mode

Enable Packer debug mode:
```bash
# Set environment variable
export PACKER_LOG=1
export PACKER_LOG_PATH=packer-debug.log

# Run build
packer build ami/setup-aws-base-image.pkr.hcl

# View logs
tail -f packer-debug.log
```

### Build Takes Too Long

**Problem**: Packer build is slow

```bash
# Use faster instance type
variable "instance_type" {
  default = "t4g.small"  # Faster than t4g.nano
}

# Use faster EBS volume
source "amazon-ebs" "example" {
  # ...
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_type = "gp3"
    volume_size = 10
    iops        = 3000
    throughput  = 125
  }
}
```

### AMI Already Exists

**Problem**: AMI with same name exists

```bash
# Add timestamp to name
ami_name = "base-ubuntu-arm64-{{timestamp}}"

# Or use UUIDs
ami_name = "base-ubuntu-arm64-{{uuid}}"
```

---

## Advanced Topics

### Multi-Region Builds

Build AMIs in multiple regions:
```hcl
build {
  sources = ["source.amazon-ebs.ubuntu_arm64"]

  provisioner "ansible" {
    playbook_file = "../playbooks/setup-docker.yml"
  }

  post-processor "amazon-ami-management" {
    regions = ["us-east-1", "us-west-2", "eu-west-1"]
    keep_n  = 3
  }
}
```

### AMI Copy to Other Regions

```bash
# Copy AMI
aws ec2 copy-image \
  --source-region us-east-1 \
  --source-image-id ami-xxxxx \
  --region us-west-2 \
  --name "ecs-ubuntu-arm64-copy"
```

### Automated AMI Builds with CI/CD

GitHub Actions example:
```yaml
name: Build AMIs

on:
  push:
    branches: [main]
    paths:
      - 'ami/**'
      - 'playbooks/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Install Packer
        run: |
          wget https://releases.hashicorp.com/packer/1.9.0/packer_1.9.0_linux_amd64.zip
          unzip packer_1.9.0_linux_amd64.zip
          sudo mv packer /usr/local/bin/

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Build AMI
        run: packer build ami/setup-aws-base-image.pkr.hcl
```

---

## Summary

This Packer setup provides:
- **6 AMI templates** for different use cases
- **Layered AMI architecture** for efficiency
- **Ansible integration** for configuration management
- **Multi-OS support** (Ubuntu, CentOS, Amazon Linux)
- **Multi-architecture support** (ARM64, AMD64)
- **Automated build process** with variables and post-processors

For deployment using these AMIs, see [DEPLOYMENT.md](../DEPLOYMENT.md).
