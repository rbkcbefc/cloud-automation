# Architecture Documentation

This document provides a comprehensive overview of the Cloud Automation Framework architecture, including system design, component interactions, networking, and security patterns.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Layered Architecture](#layered-architecture)
- [Network Architecture](#network-architecture)
- [Security Architecture](#security-architecture)
- [Component Architecture](#component-architecture)
- [Data Flow](#data-flow)
- [CI/CD Pipeline Architecture](#cicd-pipeline-architecture)
- [Multi-Environment Strategy](#multi-environment-strategy)
- [High Availability and Scalability](#high-availability-and-scalability)

## Architecture Overview

The Cloud Automation Framework follows a **multi-layered IaC architecture** that separates concerns across development, image building, infrastructure provisioning, configuration management, and application deployment.

```
┌─────────────────────────────────────────────────────────────────┐
│                     Development Layer (Vagrant)                 │
│                 Local VMs for Testing & Development              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Image Layer (Packer)                        │
│              Build Golden AMIs with Pre-configured Software      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer (Terraform)                │
│        Provision AWS Resources (VPC, EC2, ECS, ALB, etc.)       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                 Configuration Layer (Ansible)                    │
│            Runtime Configuration & Secret Management             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   Application Layer (GitHub Actions)             │
│          Build, Containerize, and Deploy Microservices           │
└─────────────────────────────────────────────────────────────────┘
```

## Layered Architecture

### 1. Development Layer (Vagrant)

**Purpose**: Local development and testing of Ansible roles/playbooks before cloud deployment.

**Components**:
- `Vagrantfile_ubuntu` - Ubuntu ARM64/AMD64 VMs
- `Vagrantfile_centos` - CentOS Stream 9 ARM64/AMD64 VMs

**Benefits**:
- Fast iteration cycles
- No cloud costs during development
- Identical OS environments as production AMIs
- Test Ansible playbooks locally

**Workflow**:
```
Developer → Write Ansible Role → Test on Vagrant VM → Validate → Commit
```

### 2. Image Layer (Packer)

**Purpose**: Build immutable, pre-configured AMIs for AWS EC2 instances.

**Image Hierarchy**:
```
Base Image (basic_utils)
    ├─→ Docker Image (+ Docker CE)
    │       ├─→ ECR Helper Image (+ ECR credentials)
    │       └─→ ECS Agent Image (+ ECS agent)
    │               └─→ ECR-ECS Combined Image
    └─→ Containerd Image (+ containerd + crictl)
            └─→ Kubernetes Node Image (+ kubeadm + kubelet)
```

**Key Packer Files**:
- `setup-aws-base-image.pkr.hcl` - Foundation image
- `setup-aws-docker-image.pkr.hcl` - Docker runtime
- `setup-aws-containerd-image.pkr.hcl` - Containerd runtime
- `setup-aws-ecr-ecs-image.pkr.hcl` - ECS-ready image

**Build Process**:
1. Packer launches temporary EC2 instance
2. Runs Ansible playbook provisioner
3. Creates AMI snapshot
4. Terminates temporary instance
5. Registers AMI in AWS account

### 3. Infrastructure Layer (Terraform)

**Purpose**: Provision and manage AWS cloud resources using Infrastructure as Code.

**Module Organization**:
```
modules/aws/infra/
├── provider/           # AWS provider config, S3 backend
├── vpc/                # VPC, subnets, route tables, gateways
├── security-group/     # Security groups for various components
├── ec2-instance/       # EC2 instance provisioning
├── launch-template/    # Launch templates for ASG
├── asg/                # Auto Scaling Groups
├── alb/                # Application Load Balancer
├── alb-https/          # HTTPS listener and certificates
├── target-group/       # ALB target groups
├── ecs/
│   ├── cluster/        # ECS cluster
│   └── service/        # ECS service definitions
├── ecr/                # Container registries
├── iam-role/           # IAM roles
├── iam-policy/         # IAM policies
├── route53/
│   ├── hosted-zone/    # DNS zones
│   ├── acm/            # SSL certificates
│   └── simple-routing-policy/  # DNS records
└── ssm-document/       # Systems Manager documents
```

**State Management**:
- Remote state stored in S3
- State locking using DynamoDB
- Separate state files per environment

### 4. Configuration Layer (Ansible)

**Purpose**: Runtime configuration, secret management, and post-provisioning tasks.

**Ansible Roles**:

| Role | Purpose | Key Tasks |
|------|---------|-----------|
| `basic_utils` | Install common utilities | git, curl, wget, vim, htop, OS-specific packages |
| `docker` | Docker CE installation | Docker daemon, post-install config, overlay2 storage |
| `containerd` | Containerd runtime | containerd, runc, crictl, systemd integration |
| `ecr-helper` | ECR credential helper | AWS ECR authentication for Docker |
| `ecs-agent` | ECS agent | ECS agent installation, cluster registration |
| `aws-ssm-agent` | SSM Session Manager | SSM agent for secure shell access |
| `setup-actions-runner` | GitHub Actions runner | Self-hosted runner installation and registration |
| `k8s-kubeadm-sh` | Kubernetes cluster | kubeadm, kubelet, kubectl, cluster initialization |

**Integration with Terraform**:
- Terraform uses `local-exec` provisioner
- Runs Ansible playbooks via bastion host
- Passes dynamic inventory from Terraform outputs

### 5. Application Layer (GitHub Actions)

**Purpose**: CI/CD pipeline for building and deploying containerized applications.

**Workflow**:
```
Code Push → GitHub Actions → Self-Hosted Runner → Build Docker Image
    → Push to ECR → Deploy to ECS → Health Check → Traffic Routing
```

## Network Architecture

### VPC Design

```
┌────────────────────────────────────────────────────────────────────┐
│                         AWS VPC (10.0.0.0/16)                      │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ Availability Zone 1 (us-east-1a)                             │ │
│  │                                                               │ │
│  │  ┌────────────────────────┐  ┌──────────────────────────┐  │ │
│  │  │ Public Subnet          │  │ Private Subnet           │  │ │
│  │  │ 10.0.1.0/24            │  │ 10.0.3.0/24              │  │ │
│  │  │                        │  │                          │  │ │
│  │  │ • Bastion Host         │  │ • ECS Instances          │  │ │
│  │  │ • NAT Gateway          │  │ • K8s Data Plane Nodes   │  │ │
│  │  │ • ALB                  │  │ • GitHub Actions Runners │  │ │
│  │  │ • K8s Control Plane    │  │                          │  │ │
│  │  └────────────────────────┘  └──────────────────────────┘  │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ Availability Zone 2 (us-east-1b)                             │ │
│  │                                                               │ │
│  │  ┌────────────────────────┐  ┌──────────────────────────┐  │ │
│  │  │ Public Subnet          │  │ Private Subnet           │  │ │
│  │  │ 10.0.2.0/24            │  │ 10.0.4.0/24              │  │ │
│  │  │                        │  │                          │  │ │
│  │  │ • ALB (multi-AZ)       │  │ • ECS Instances          │  │ │
│  │  └────────────────────────┘  └──────────────────────────┘  │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  Internet Gateway ←→ Public Subnets                                │
│  NAT Gateway ←→ Private Subnets → Internet                        │
└────────────────────────────────────────────────────────────────────┘
```

### Subnetting Strategy

| Subnet Type | CIDR | Purpose | Internet Access |
|-------------|------|---------|-----------------|
| Public Subnet AZ1 | 10.0.1.0/24 | Bastion, NAT, ALB, K8s CP | Direct (IGW) |
| Public Subnet AZ2 | 10.0.2.0/24 | ALB (multi-AZ) | Direct (IGW) |
| Private Subnet AZ1 | 10.0.3.0/24 | ECS, K8s workers, runners | NAT Gateway |
| Private Subnet AZ2 | 10.0.4.0/24 | ECS (multi-AZ) | NAT Gateway |

### Routing Tables

**Public Subnet Route Table**:
```
Destination         Target
10.0.0.0/16         local
0.0.0.0/0           Internet Gateway
```

**Private Subnet Route Table**:
```
Destination         Target
10.0.0.0/16         local
0.0.0.0/0           NAT Gateway
```

## Security Architecture

### Defense in Depth

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Network Security                               │
│ • VPC isolation                                         │
│ • Private subnets for workloads                         │
│ • Security groups (stateful firewall)                   │
│ • Network ACLs (stateless firewall)                     │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 2: Access Control                                 │
│ • Bastion host for SSH access                           │
│ • SSH key-based authentication                          │
│ • AWS SSM Session Manager                               │
│ • IAM roles and policies                                │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Application Security                           │
│ • HTTPS/TLS encryption (ACM certificates)               │
│ • Container isolation                                   │
│ • Secrets management (Ansible Vault)                    │
│ • ECR image scanning                                    │
└─────────────────────────────────────────────────────────┘
```

### Security Groups

| Security Group | Purpose | Inbound Rules |
|----------------|---------|---------------|
| `bastion-host-sg` | Bastion host | SSH (22) from admin IPs |
| `ecs-host-bridge-network-sg` | ECS instances | 32768-65535 from ALB SG |
| `external-web-alb-sg` | Application Load Balancer | HTTP (80), HTTPS (443) from 0.0.0.0/0 |
| `internal-host-sg` | Internal communication | All traffic from VPC CIDR |
| `k8s-cp-host-sg` | K8s control plane | 6443 from workers, 22 from bastion |
| `k8s-dp-host-sg` | K8s data plane | 10250, 30000-32767 from CP, 22 from bastion |

### Bastion Host Architecture

The bastion host provides secure SSH access to private resources:

```
Developer Laptop
       ↓ (SSH)
Bastion Host (Public Subnet)
       ↓ (SSH with Agent Forwarding)
Target Host (Private Subnet)
```

**Access Pattern**:
```bash
# Method 1: SSH with jump host
ssh -J user@bastion-ip user@target-ip

# Method 2: SSH through bastion
ssh -A user@bastion-ip
ssh user@target-ip
```

### IAM Roles and Policies

**EC2 Instance Role** (`ec2-core`):
- EC2 basic operations
- S3 access for artifacts
- CloudWatch logging
- SSM Session Manager

**ECS Task Execution Role**:
- Pull images from ECR
- Write logs to CloudWatch
- Retrieve secrets from Secrets Manager

**GitHub Actions Runner Role**:
- Push images to ECR
- Update ECS services
- Read/write S3 artifacts

## Component Architecture

### ECS Architecture (Bridge Mode)

```
┌────────────────────────────────────────────────────────────────┐
│                    Application Load Balancer                   │
│                   (external-web-alb)                            │
│                 HTTPS:443 → HTTP:80                             │
└────────────────────────────────────────────────────────────────┘
                            ↓
        ┌───────────────────┴───────────────────┐
        ↓                                       ↓
┌──────────────────┐                   ┌──────────────────┐
│  Target Group    │                   │  Target Group    │
│ (mock-email-svc) │                   │ (mock-nasa-api)  │
└──────────────────┘                   └──────────────────┘
        ↓                                       ↓
┌──────────────────┐                   ┌──────────────────┐
│   ECS Service    │                   │   ECS Service    │
│  (Email Service) │                   │  (NASA API)      │
└──────────────────┘                   └──────────────────┘
        ↓                                       ↓
┌──────────────────────────────────────────────────────────┐
│                    ECS Cluster                            │
│                                                           │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Auto Scaling Group                              │    │
│  │                                                  │    │
│  │  ┌──────────────┐  ┌──────────────┐           │    │
│  │  │ EC2 Instance │  │ EC2 Instance │           │    │
│  │  │              │  │              │           │    │
│  │  │ ECS Agent    │  │ ECS Agent    │    ...    │    │
│  │  │ Container 1  │  │ Container 1  │           │    │
│  │  │ Container 2  │  │ Container 2  │           │    │
│  │  └──────────────┘  └──────────────┘           │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

**ECS Bridge Mode Networking**:
- Containers use Docker bridge network
- Port mapping: Host port → Container port
- ECS agent manages port allocation
- ALB routes traffic to dynamic host ports (32768-65535)

### Kubernetes Architecture

```
┌────────────────────────────────────────────────────────┐
│            Control Plane Node (Public Subnet)          │
│                                                         │
│  • kube-apiserver (port 6443)                          │
│  • kube-controller-manager                             │
│  • kube-scheduler                                      │
│  • etcd (cluster state)                                │
│  • Calico CNI                                          │
└────────────────────────────────────────────────────────┘
                        ↓
        ┌───────────────┴───────────────┐
        ↓                               ↓
┌───────────────────┐          ┌───────────────────┐
│ Data Plane Node 1 │          │ Data Plane Node 2 │
│ (Private Subnet)  │          │ (Private Subnet)  │
│                   │          │                   │
│ • kubelet         │          │ • kubelet         │
│ • kube-proxy      │          │ • kube-proxy      │
│ • containerd      │          │ • containerd      │
│ • Calico agent    │          │ • Calico agent    │
│                   │          │                   │
│ Pods:             │          │ Pods:             │
│ • mock-email-svc  │          │ • mock-email-svc  │
└───────────────────┘          └───────────────────┘
```

**Networking**:
- **CNI**: Calico for pod networking
- **Service Type**: LoadBalancer (MetalLB or cloud provider)
- **Pod CIDR**: Configured during kubeadm init
- **Service CIDR**: Separate from pod network

## Data Flow

### CI/CD Pipeline Data Flow

```
1. Developer Push
   └→ GitHub Repository
       └→ GitHub Actions Trigger
           └→ Self-Hosted Runner (EC2)
               ├→ Build Java Application
               ├→ Build Docker Image
               ├→ Push to ECR
               └→ Update ECS Service
                   └→ ECS Task Definition Update
                       └→ Rolling Deployment
                           └→ ALB Health Check
                               └→ Traffic Routing
```

### ECS Deployment Flow

```
ECR (Container Image)
    ↓
ECS Service (Task Definition)
    ↓
ECS Task Scheduler
    ↓
ECS Agent (pulls image)
    ↓
Docker Container (running on EC2)
    ↓
ALB Target Group (health check)
    ↓
ALB Listener (route traffic)
    ↓
User Request
```

### Terraform Provisioning Flow

```
terraform apply
    ↓
Create VPC & Subnets
    ↓
Create Security Groups
    ↓
Create IAM Roles
    ↓
Launch EC2 Instances (from AMI)
    ↓
Wait for cloud-init (SSM document)
    ↓
Execute Ansible (via local-exec)
    ↓
Configure Services
    ↓
Register with ALB/ECS
```

## CI/CD Pipeline Architecture

### GitHub Actions Self-Hosted Runner

```
┌──────────────────────────────────────────────────────────┐
│                  GitHub Repository                        │
│              (mock-email-service)                         │
│                                                           │
│  .github/workflows/build-self-runner-arm64.yml           │
└──────────────────────────────────────────────────────────┘
                        ↓ (webhook)
┌──────────────────────────────────────────────────────────┐
│            Self-Hosted Runner (EC2 - ARM64)              │
│                                                           │
│  Steps:                                                   │
│  1. Checkout code                                        │
│  2. Build JAR (Maven/Gradle)                             │
│  3. Build Docker image                                   │
│  4. Authenticate to ECR                                  │
│  5. Push image to ECR                                    │
│  6. Update ECS task definition                           │
│  7. Deploy new ECS service                               │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│                Amazon ECR Repository                      │
│          (mock-email-service:latest)                      │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│                  ECS Service Deployment                   │
│                 (Rolling Update)                          │
└──────────────────────────────────────────────────────────┘
```

## Multi-Environment Strategy

### Environment Isolation

```
┌─────────────────────────────────────────────────────────┐
│                     AWS Account                          │
│                                                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐       │
│  │  Nightly   │  │     QA     │  │   Staging  │  ...  │
│  │    VPC     │  │    VPC     │  │    VPC     │       │
│  │ 10.0.0.0/16│  │ 10.1.0.0/16│  │ 10.2.0.0/16│       │
│  └────────────┘  └────────────┘  └────────────┘       │
│                                                          │
│  Shared Resources:                                       │
│  • Route53 Hosted Zone (agilealm.click)                 │
│  • ACM Certificates                                      │
│  • S3 Terraform State Buckets                           │
│  • DynamoDB State Lock Tables                           │
└─────────────────────────────────────────────────────────┘
```

### Configuration Management

**Central Configuration**: `envs/aws/aws-config.yml`

```yaml
environments:
  nightly:
    region: us-east-1
    vpc_cidr: 10.0.0.0/16
    ami_id: ami-xxxxx
    instance_type: t4g.medium

  qa:
    region: us-east-1
    vpc_cidr: 10.1.0.0/16
    ami_id: ami-yyyyy
    instance_type: t4g.small
```

**Terraform Backend Separation**:
- `backend-s3-nightly.conf`
- `backend-s3-qa.conf`
- `backend-s3-staging.conf`
- `backend-s3-prod.conf`

## High Availability and Scalability

### ECS High Availability

- **Multi-AZ Deployment**: ECS instances across 2 availability zones
- **Auto Scaling Group**: Scales based on CPU/memory metrics
- **Application Load Balancer**: Distributes traffic across instances
- **Health Checks**: ALB monitors container health
- **Rolling Updates**: Zero-downtime deployments

### Kubernetes High Availability

**Current Setup** (Development):
- 1 Control Plane Node
- 2 Data Plane Nodes

**Production Recommendation**:
- 3 Control Plane Nodes (etcd quorum)
- 3+ Data Plane Nodes
- External etcd cluster
- Multi-AZ distribution

### Scalability Patterns

| Component | Scaling Strategy |
|-----------|------------------|
| **ECS Instances** | Horizontal (ASG) |
| **ECS Tasks** | Horizontal (Task count) |
| **ALB** | Automatic (AWS managed) |
| **K8s Pods** | Horizontal Pod Autoscaler |
| **K8s Nodes** | Cluster Autoscaler |
| **ECR** | Unlimited (AWS managed) |

## Disaster Recovery

### Backup Strategy

- **Terraform State**: Versioned in S3 with encryption
- **AMI Snapshots**: Automated EBS snapshots
- **Ansible Vault**: Backed up securely
- **Kubernetes etcd**: Snapshot backups
- **Application Data**: S3 with versioning

### Recovery Procedures

1. **Infrastructure Recovery**: Re-run Terraform apply
2. **Application Recovery**: Redeploy from ECR images
3. **Configuration Recovery**: Re-run Ansible playbooks
4. **Data Recovery**: Restore from S3/snapshots

## Summary

This architecture provides:

- **Modularity**: Reusable Terraform modules and Ansible roles
- **Scalability**: Auto-scaling ECS and Kubernetes workloads
- **Security**: Defense-in-depth with bastion hosts, security groups, and encryption
- **Automation**: End-to-end CI/CD with GitHub Actions
- **Multi-Environment**: Isolated environments for testing and production
- **Flexibility**: Support for both ECS and Kubernetes orchestration
- **Observability**: CloudWatch logging and monitoring integration

The layered approach ensures separation of concerns, making the system maintainable, testable, and production-ready.
