# Terraform Documentation

This document provides comprehensive documentation for all Terraform modules and infrastructure provisioning in the Cloud Automation Framework.

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [State Management](#state-management)
- [Terraform Modules](#terraform-modules)
- [Environment Configuration](#environment-configuration)
- [Provisioning Order](#provisioning-order)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

Terraform is used to provision and manage AWS infrastructure as code. The project uses:

- **Reusable Modules**: Located in `modules/aws/infra/`
- **Environment-Specific Deployments**: Located in `envs/aws/infra/`
- **Remote State Management**: S3 backend with DynamoDB locking
- **Multi-Environment Support**: Nightly, QA, Staging, Production

## Directory Structure

```
cloud-automation/
├── modules/
│   └── aws/
│       └── infra/
│           ├── provider/          # AWS provider configuration
│           ├── vpc/               # VPC module
│           ├── security-group/    # Security group modules
│           ├── ec2-instance/      # EC2 instance module
│           ├── launch-template/   # Launch template module
│           ├── asg/               # Auto Scaling Group module
│           ├── alb/               # Application Load Balancer module
│           ├── alb-https/         # HTTPS listener module
│           ├── target-group/      # ALB target group module
│           ├── ecs/
│           │   ├── cluster/       # ECS cluster module
│           │   └── service/       # ECS service module
│           ├── ecr/               # Elastic Container Registry module
│           ├── iam-role/          # IAM role modules
│           ├── iam-policy/        # IAM policy modules
│           ├── route53/           # Route53 modules
│           └── ssm-document/      # SSM document module
└── envs/
    └── aws/
        ├── aws-config.yml                # Central configuration
        ├── backend-s3-nightly.conf       # Backend config (nightly)
        ├── backend-s3-qa.conf            # Backend config (QA)
        ├── backend-s3-staging.conf       # Backend config (staging)
        ├── backend-s3-prod.conf          # Backend config (production)
        ├── config/
        │   ├── backend-s3-k8s-kubeadm-sh.conf  # K8s backend config
        │   └── k8s-kubeadm-sh.yml        # K8s configuration
        ├── infra/                        # Infrastructure definitions
        │   ├── provider/
        │   │   ├── nightly/
        │   │   ├── qa/
        │   │   ├── staging/
        │   │   ├── prod/
        │   │   └── k8s-kubeadm-sh/
        │   ├── vpc/
        │   ├── security-group/
        │   ├── ec2-instances/
        │   ├── ecs/
        │   ├── ecr/
        │   ├── iam-role/
        │   ├── iam-policy/
        │   ├── route53/
        │   ├── ssm-document/
        │   └── k8s/
        └── app/                          # Application deployments
            ├── mock-email-service/
            └── mock-nasa-sound-api-service/
```

## State Management

### S3 Backend Configuration

Terraform state is stored remotely in S3 with DynamoDB for state locking.

**Backend Configuration File** (`backend-s3-nightly.conf`):
```hcl
bucket         = "your-terraform-state-bucket"
key            = "nightly/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

### Create S3 Backend

```bash
# Create S3 bucket
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Initialize Terraform

```bash
terraform init -backend-config=backend-s3-nightly.conf
```

---

## Terraform Modules

### 1. provider

**Purpose**: Configure AWS provider and Terraform backend

**Location**: `modules/aws/infra/provider/`

**Usage Example**:
```hcl
# envs/aws/infra/provider/nightly/main.tf
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configured via -backend-config flag
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "nightly"
      ManagedBy   = "Terraform"
      Project     = "cloud-automation"
    }
  }
}
```

**Commands**:
```bash
cd envs/aws/infra/provider/nightly
terraform init -backend-config=../../backend-s3-nightly.conf
terraform apply
```

---

### 2. vpc

**Purpose**: Create VPC with public and private subnets

**Location**: `modules/aws/infra/vpc/`

**Inputs**:
| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `vpc_cidr` | string | VPC CIDR block | `10.0.0.0/16` |
| `availability_zones` | list(string) | AZs for subnets | `["us-east-1a", "us-east-1b"]` |
| `public_subnet_cidrs` | list(string) | Public subnet CIDRs | `["10.0.1.0/24", "10.0.2.0/24"]` |
| `private_subnet_cidrs` | list(string) | Private subnet CIDRs | `["10.0.3.0/24", "10.0.4.0/24"]` |
| `enable_nat_gateway` | bool | Create NAT gateway | `true` |
| `environment` | string | Environment name | Required |

**Outputs**:
- `vpc_id` - VPC ID
- `public_subnet_ids` - List of public subnet IDs
- `private_subnet_ids` - List of private subnet IDs
- `nat_gateway_id` - NAT Gateway ID

**Usage Example**:
```hcl
module "vpc" {
  source = "../../../../modules/aws/infra/vpc"

  vpc_cidr               = "10.0.0.0/16"
  availability_zones     = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs   = ["10.0.3.0/24", "10.0.4.0/24"]
  enable_nat_gateway     = true
  environment            = "nightly"

  tags = {
    Project = "cloud-automation"
  }
}
```

**Resources Created**:
- VPC
- Internet Gateway
- NAT Gateway (in public subnet)
- Public subnets (2 AZs)
- Private subnets (2 AZs)
- Route tables and associations

---

### 3. security-group

**Purpose**: Create security groups for different components

**Location**: `modules/aws/infra/security-group/`

**Available Security Groups**:
- `bastion-host` - Bastion host security group
- `ecs-host-bridge-network` - ECS instances
- `external-web-alb` - Public-facing ALB
- `internal-host` - Internal communication
- `k8s-kubeadm-sh-cp-host` - Kubernetes control plane
- `k8s-kubeadm-sh-dp-host` - Kubernetes data plane

**Bastion Host Security Group**:

Inputs:
| Variable | Type | Description |
|----------|------|-------------|
| `vpc_id` | string | VPC ID |
| `allowed_ssh_cidrs` | list(string) | CIDRs allowed to SSH |
| `environment` | string | Environment name |

```hcl
module "bastion_sg" {
  source = "../../../../../modules/aws/infra/security-group/bastion-host"

  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  allowed_ssh_cidrs  = ["1.2.3.4/32"]  # Your IP
  environment        = "nightly"
}
```

Inbound Rules:
- SSH (22) from allowed_ssh_cidrs

Outbound Rules:
- All traffic to 0.0.0.0/0

---

### 4. ec2-instance

**Purpose**: Launch EC2 instances with optional Ansible provisioning

**Location**: `modules/aws/infra/ec2-instance/`

**Inputs**:
| Variable | Type | Description |
|----------|------|-------------|
| `ami_id` | string | AMI ID to use |
| `instance_type` | string | EC2 instance type |
| `key_name` | string | SSH key pair name |
| `subnet_id` | string | Subnet ID |
| `security_group_ids` | list(string) | Security group IDs |
| `iam_instance_profile` | string | IAM instance profile name |
| `user_data` | string | User data script (optional) |
| `associate_public_ip` | bool | Assign public IP |
| `tags` | map(string) | Resource tags |
| `run_ansible` | bool | Run Ansible provisioner |
| `ansible_playbook` | string | Playbook path |
| `bastion_host` | string | Bastion host IP for Ansible |

**Outputs**:
- `instance_id` - EC2 instance ID
- `private_ip` - Private IP address
- `public_ip` - Public IP address

**Usage Example**:
```hcl
module "bastion_host" {
  source = "../../../../../modules/aws/infra/ec2-instance"

  ami_id                 = "ami-0123456789abcdef0"
  instance_type          = "t4g.nano"
  key_name               = "cloud-automation-key"
  subnet_id              = data.terraform_remote_state.vpc.outputs.public_subnet_ids[0]
  security_group_ids     = [module.bastion_sg.security_group_id]
  iam_instance_profile   = data.terraform_remote_state.iam.outputs.ec2_instance_profile_name
  associate_public_ip    = true

  tags = {
    Name        = "bastion-host-nightly"
    Environment = "nightly"
    Role        = "bastion"
  }
}
```

**Features**:
- Waits for cloud-init to complete using SSM document
- Optionally runs Ansible playbook via local-exec
- Supports provisioning via bastion host

---

### 5. launch-template

**Purpose**: Create launch template for Auto Scaling Groups

**Location**: `modules/aws/infra/launch-template/`

**Inputs**:
| Variable | Type | Description |
|----------|------|-------------|
| `ami_id` | string | AMI ID |
| `instance_type` | string | Instance type |
| `key_name` | string | SSH key pair |
| `security_group_ids` | list(string) | Security groups |
| `iam_instance_profile` | string | IAM instance profile |
| `user_data` | string | User data script |
| `environment` | string | Environment name |

**Outputs**:
- `launch_template_id` - Launch template ID
- `launch_template_latest_version` - Latest version number

**Usage Example**:
```hcl
module "ecs_launch_template" {
  source = "../../../../../../modules/aws/infra/launch-template"

  ami_id               = "ami-ecs-xxxxx"
  instance_type        = "t4g.medium"
  key_name             = "cloud-automation-key"
  security_group_ids   = [data.terraform_remote_state.sg.outputs.ecs_host_sg_id]
  iam_instance_profile = data.terraform_remote_state.iam.outputs.ec2_instance_profile_name
  user_data            = file("${path.module}/user_data.sh")
  environment          = "nightly"
}
```

---

### 6. asg

**Purpose**: Create Auto Scaling Group

**Location**: `modules/aws/infra/asg/`

**Inputs**:
| Variable | Type | Description |
|----------|------|-------------|
| `launch_template_id` | string | Launch template ID |
| `min_size` | number | Minimum instances |
| `max_size` | number | Maximum instances |
| `desired_capacity` | number | Desired instances |
| `subnet_ids` | list(string) | Subnet IDs |
| `target_group_arns` | list(string) | ALB target groups (optional) |
| `health_check_type` | string | Health check type |
| `environment` | string | Environment name |

**Outputs**:
- `autoscaling_group_id` - ASG ID
- `autoscaling_group_arn` - ASG ARN

**Usage Example**:
```hcl
module "ecs_asg" {
  source = "../../../../../../modules/aws/infra/asg"

  launch_template_id = module.ecs_launch_template.launch_template_id
  min_size           = 1
  max_size           = 5
  desired_capacity   = 2
  subnet_ids         = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  health_check_type  = "EC2"
  environment        = "nightly"

  tags = {
    Name = "ecs-asg-nightly"
  }
}
```

---

### 7. alb

**Purpose**: Create Application Load Balancer

**Location**: `modules/aws/infra/alb/`

**Inputs**:
| Variable | Type | Description |
|----------|------|-------------|
| `name` | string | ALB name |
| `internal` | bool | Internal ALB |
| `security_group_ids` | list(string) | Security groups |
| `subnet_ids` | list(string) | Subnet IDs (minimum 2) |
| `environment` | string | Environment name |

**Outputs**:
- `alb_id` - ALB ID
- `alb_arn` - ALB ARN
- `alb_dns_name` - ALB DNS name
- `alb_zone_id` - ALB Route53 zone ID

**Usage Example**:
```hcl
module "ecs_alb" {
  source = "../../../../../../modules/aws/infra/alb"

  name               = "ecs-alb-nightly"
  internal           = false
  security_group_ids = [data.terraform_remote_state.sg.outputs.external_web_alb_sg_id]
  subnet_ids         = data.terraform_remote_state.vpc.outputs.public_subnet_ids
  environment        = "nightly"
}
```

---

### 8. target-group

**Purpose**: Create ALB target group

**Location**: `modules/aws/infra/target-group/`

**Inputs**:
| Variable | Type | Description |
|----------|------|-------------|
| `name` | string | Target group name |
| `port` | number | Target port |
| `protocol` | string | Protocol (HTTP/HTTPS) |
| `vpc_id` | string | VPC ID |
| `health_check_path` | string | Health check path |
| `health_check_interval` | number | Health check interval (seconds) |
| `health_check_timeout` | number | Health check timeout (seconds) |
| `healthy_threshold` | number | Healthy threshold count |
| `unhealthy_threshold` | number | Unhealthy threshold count |
| `target_type` | string | Target type (instance/ip) |
| `environment` | string | Environment name |

**Outputs**:
- `target_group_id` - Target group ID
- `target_group_arn` - Target group ARN

**Usage Example**:
```hcl
module "mock_email_tg" {
  source = "../../../../../../../modules/aws/infra/target-group"

  name                   = "mock-email-tg-nightly"
  port                   = 8080
  protocol               = "HTTP"
  vpc_id                 = data.terraform_remote_state.vpc.outputs.vpc_id
  health_check_path      = "/mockemailservice/health"
  health_check_interval  = 30
  health_check_timeout   = 5
  healthy_threshold      = 2
  unhealthy_threshold    = 2
  target_type            = "instance"
  environment            = "nightly"
}
```

---

### 9. alb-https

**Purpose**: Create HTTPS listener for ALB

**Location**: `modules/aws/infra/alb-https/`

**Inputs**:
| Variable | Type | Description |
|----------|------|-------------|
| `alb_arn` | string | ALB ARN |
| `certificate_arn` | string | ACM certificate ARN |
| `default_target_group_arn` | string | Default target group ARN |
| `ssl_policy` | string | SSL policy |

**Outputs**:
- `https_listener_arn` - HTTPS listener ARN

**Usage Example**:
```hcl
module "alb_https" {
  source = "../../../../../../modules/aws/infra/alb-https"

  alb_arn                    = module.ecs_alb.alb_arn
  certificate_arn            = data.terraform_remote_state.acm.outputs.certificate_arn
  default_target_group_arn   = module.mock_email_tg.target_group_arn
  ssl_policy                 = "ELBSecurityPolicy-TLS-1-2-2017-01"
}
```

---

### 10. ecs/cluster

**Purpose**: Create ECS cluster

**Location**: `modules/aws/infra/ecs/cluster/`

**Inputs**:
| Variable | Type | Description |
|----------|------|-------------|
| `cluster_name` | string | ECS cluster name |
| `capacity_providers` | list(string) | Capacity providers |
| `environment` | string | Environment name |

**Outputs**:
- `cluster_id` - ECS cluster ID
- `cluster_arn` - ECS cluster ARN
- `cluster_name` - ECS cluster name

**Usage Example**:
```hcl
module "ecs_cluster" {
  source = "../../../../../../modules/aws/infra/ecs/cluster"

  cluster_name        = "ecs-cluster-nightly"
  capacity_providers  = ["FARGATE", "FARGATE_SPOT"]
  environment         = "nightly"
}
```

---

### 11. ecs/service

**Purpose**: Create ECS service

**Location**: `modules/aws/infra/ecs/service/`

**Inputs**:
| Variable | Type | Description |
|----------|------|-------------|
| `service_name` | string | ECS service name |
| `cluster_id` | string | ECS cluster ID |
| `task_definition_arn` | string | Task definition ARN |
| `desired_count` | number | Desired task count |
| `launch_type` | string | Launch type (EC2/FARGATE) |
| `target_group_arn` | string | ALB target group ARN |
| `container_name` | string | Container name |
| `container_port` | number | Container port |
| `environment` | string | Environment name |

**Usage Example**:
```hcl
module "mock_email_service" {
  source = "../../../../../../../modules/aws/infra/ecs/service"

  service_name         = "mock-email-service"
  cluster_id           = data.terraform_remote_state.ecs_cluster.outputs.cluster_id
  task_definition_arn  = aws_ecs_task_definition.mock_email.arn
  desired_count        = 2
  launch_type          = "EC2"
  target_group_arn     = data.terraform_remote_state.tg.outputs.mock_email_tg_arn
  container_name       = "mock-email-service"
  container_port       = 8080
  environment          = "nightly"
}
```

---

### 12. ecr

**Purpose**: Create Elastic Container Registry repository

**Location**: `modules/aws/infra/ecr/`

**Inputs**:
| Variable | Type | Description |
|----------|------|-------------|
| `repository_name` | string | ECR repository name |
| `image_tag_mutability` | string | Tag mutability (MUTABLE/IMMUTABLE) |
| `scan_on_push` | bool | Scan images on push |
| `lifecycle_policy` | string | Lifecycle policy JSON |
| `environment` | string | Environment name |

**Outputs**:
- `repository_url` - ECR repository URL
- `repository_arn` - ECR repository ARN

**Usage Example**:
```hcl
module "mock_email_ecr" {
  source = "../../../../../../modules/aws/infra/ecr"

  repository_name       = "mock-email-service"
  image_tag_mutability  = "MUTABLE"
  scan_on_push          = true
  lifecycle_policy      = templatefile("${path.module}/lifecycle-policy.json", {})
  environment           = "nightly"
}
```

**Lifecycle Policy Example**:
```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

---

### 13. iam-role

**Purpose**: Create IAM roles

**Location**: `modules/aws/infra/iam-role/`

**Available Roles**:
- `ec2-core` - EC2 instance role
- `ecs-task-execution` - ECS task execution role

**EC2 Core Role Example**:
```hcl
module "ec2_role" {
  source = "../../../../../../../modules/aws/infra/iam-role/ec2-core"

  role_name    = "ec2-core-role-nightly"
  policy_arns  = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    data.terraform_remote_state.iam_policy.outputs.ec2_core_policy_arn
  ]
  environment  = "nightly"
}
```

---

### 14. route53

**Purpose**: Manage DNS records and certificates

**Location**: `modules/aws/infra/route53/`

**Available Modules**:
- `hosted-zone` - Create Route53 hosted zone
- `acm` - Request ACM certificate
- `simple-routing-policy` - Create CNAME/A records

**Usage Example**:
```hcl
# Hosted Zone
module "hosted_zone" {
  source = "../../../../../../modules/aws/infra/route53/hosted-zone"

  domain_name = "agilealm.click"
}

# ACM Certificate
module "acm_cert" {
  source = "../../../../../../modules/aws/infra/route53/acm"

  domain_name          = "mockemailservice.agilealm.click"
  hosted_zone_id       = module.hosted_zone.zone_id
  validation_method    = "DNS"
}

# CNAME Record
module "cname_record" {
  source = "../../../../../../modules/aws/infra/route53/simple-routing-policy"

  hosted_zone_id = module.hosted_zone.zone_id
  record_name    = "mockemailservice"
  record_type    = "CNAME"
  ttl            = 300
  records        = [module.ecs_alb.alb_dns_name]
}
```

---

### 15. ssm-document

**Purpose**: Create SSM documents

**Location**: `modules/aws/infra/ssm-document/`

**cloud-init-wait Document**:

Purpose: Wait for cloud-init to complete before running Ansible

```hcl
module "cloud_init_wait" {
  source = "../../../../../../../modules/aws/infra/ssm-document/cloud-init-wait"

  document_name = "cloud-init-wait-nightly"
  environment   = "nightly"
}
```

---

## Environment Configuration

### aws-config.yml

Central configuration file for all environments:

```yaml
environments:
  nightly:
    region: us-east-1
    vpc_cidr: 10.0.0.0/16
    availability_zones:
      - us-east-1a
      - us-east-1b
    public_subnets:
      - 10.0.1.0/24
      - 10.0.2.0/24
    private_subnets:
      - 10.0.3.0/24
      - 10.0.4.0/24
    ami_id_base: ami-base-xxxxx
    ami_id_docker: ami-docker-xxxxx
    ami_id_ecs: ami-ecs-xxxxx
    ami_id_containerd: ami-containerd-xxxxx
    instance_type_bastion: t4g.nano
    instance_type_ecs: t4g.medium
    key_name: cloud-automation-key

  qa:
    region: us-east-1
    vpc_cidr: 10.1.0.0/16
    # ... similar configuration
```

---

## Provisioning Order

**Critical**: Resources must be provisioned in this order due to dependencies:

1. **Provider** - Configure Terraform backend
2. **VPC** - Network foundation
3. **Security Groups** - Firewall rules
4. **IAM Roles & Policies** - Permissions
5. **SSM Documents** - CloudInit wait document
6. **Bastion Host** - Secure access
7. **ECR Repositories** - Container registry
8. **ECS Launch Template** - EC2 launch configuration
9. **ECS Auto Scaling Group** - EC2 instances
10. **ECS Cluster** - Container orchestration
11. **ALB** - Load balancer
12. **Target Groups** - ALB targets
13. **HTTPS Listener** - SSL termination
14. **ALB Rules** - Routing rules
15. **GitHub Actions Runners** - CI/CD infrastructure
16. **ECS Services** - Application deployment
17. **Route53** - DNS configuration

---

## Best Practices

### 1. Use Remote State

Always use S3 backend for state management:
```bash
terraform init -backend-config=backend-s3-nightly.conf
```

### 2. Use Data Sources for Dependencies

Reference other state files:
```hcl
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "your-terraform-state-bucket"
    key    = "nightly/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_instance" "example" {
  subnet_id = data.terraform_remote_state.vpc.outputs.public_subnet_ids[0]
}
```

### 3. Use Variables

Always parameterize your modules:
```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.nano"
}
```

### 4. Tag Everything

Use consistent tagging:
```hcl
tags = {
  Name        = "resource-name-${var.environment}"
  Environment = var.environment
  ManagedBy   = "Terraform"
  Project     = "cloud-automation"
}
```

### 5. Use Terraform Workspaces (Optional)

For managing multiple environments:
```bash
terraform workspace new nightly
terraform workspace select nightly
terraform apply
```

### 6. Plan Before Apply

Always review changes:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### 7. Use Modules for Reusability

Create modules for common patterns:
```hcl
module "vpc" {
  source = "../../../../modules/aws/infra/vpc"
  # ... inputs
}
```

---

## Troubleshooting

### State Lock Issues

**Problem**: State is locked by another process

```bash
# View lock info
terraform force-unlock <lock-id>

# Caution: Only use if you're sure no other process is running
```

### Backend Configuration Errors

**Problem**: Backend initialization fails

```bash
# Reconfigure backend
terraform init -reconfigure -backend-config=backend-s3-nightly.conf

# Migrate state
terraform init -migrate-state
```

### Dependency Errors

**Problem**: Resource depends on non-existent resource

```bash
# Use depends_on explicitly
resource "aws_instance" "example" {
  # ...
  depends_on = [aws_iam_role.ec2_role]
}
```

### Import Existing Resources

**Problem**: Resource already exists in AWS

```bash
# Import resource
terraform import aws_instance.example i-1234567890abcdef0

# Verify state
terraform show
```

### Debugging

Enable debug logging:
```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform-debug.log
terraform apply
```

### Refresh State

Sync state with real infrastructure:
```bash
terraform refresh
```

### Format and Validate

Check code quality:
```bash
terraform fmt -recursive
terraform validate
```

---

## Summary

This Terraform setup provides:
- **24+ reusable modules** for AWS infrastructure
- **Remote state management** with S3 and DynamoDB
- **Multi-environment support** (nightly, QA, staging, prod)
- **Modular architecture** for easy maintenance
- **Comprehensive resource coverage** (VPC, EC2, ECS, ALB, Route53, etc.)

For deployment instructions, see [DEPLOYMENT.md](../DEPLOYMENT.md).
