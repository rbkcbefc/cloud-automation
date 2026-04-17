# Deployment Guide

This comprehensive guide walks you through deploying the Cloud Automation Framework from scratch. Follow these steps in order to set up your complete AWS infrastructure.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Phase 1: Local Development Setup](#phase-1-local-development-setup)
- [Phase 2: AWS Account Configuration](#phase-2-aws-account-configuration)
- [Phase 3: Build AMIs with Packer](#phase-3-build-amis-with-packer)
- [Phase 4: Infrastructure Provisioning](#phase-4-infrastructure-provisioning)
- [Phase 5: Application Deployment](#phase-5-application-deployment)
- [Phase 6: Kubernetes Setup (Optional)](#phase-6-kubernetes-setup-optional)
- [Verification and Testing](#verification-and-testing)
- [Teardown](#teardown)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

Ensure the following tools are installed on your local machine:

```bash
# Check versions
vagrant --version      # >= 2.3.0
ansible --version      # >= 2.14.0
packer --version       # >= 1.9.0
terraform --version    # >= 1.5.0
aws --version          # >= 2.0.0
git --version          # >= 2.30.0

# macOS installation (Homebrew)
brew install vagrant ansible packer terraform awscli

# Verify VMware Desktop or VirtualBox is installed
# For ARM64 Macs, VMware Desktop is recommended
```

### Hardware Requirements

- **RAM**: Minimum 8GB (16GB recommended for running Vagrant VMs)
- **Disk Space**: At least 20GB free
- **CPU**: ARM64 (Apple Silicon) or AMD64 (Intel)
- **OS**: macOS, Linux, or Windows with WSL2

### AWS Account Requirements

- Active AWS account with billing enabled
- IAM user with administrator access
- AWS CLI configured with credentials
- Credit card on file (for EC2, ECS, and other resources)

## Pre-Deployment Checklist

- [ ] All required tools installed and versions verified
- [ ] AWS account created and accessible
- [ ] AWS CLI configured (`aws configure`)
- [ ] SSH key pair created in AWS EC2 (download `.pem` file)
- [ ] Git repository cloned locally
- [ ] Vagrant VM provider installed (VMware Desktop or VirtualBox)
- [ ] Docker installed locally (for testing)
- [ ] GitHub account (for self-hosted runners)
- [ ] Domain name registered (optional, or use provided `agilealm.click`)

## Phase 1: Local Development Setup

### 1.1 Clone Repository

```bash
# Clone the repository
git clone https://github.com/rbkcbefc/cloud-automation.git
cd cloud-automation

# Verify directory structure
ls -la
```

### 1.2 Test Ansible Playbooks Locally (Optional)

Before building AMIs, validate Ansible playbooks using Vagrant:

```bash
# Choose your OS
cp Vagrantfile_ubuntu Vagrantfile
# OR for CentOS
# cp Vagrantfile_centos Vagrantfile

# Edit Vagrantfile to select which playbook to run
# Uncomment the appropriate provisioner line

# Start VM and provision
vagrant up

# SSH into VM
vagrant ssh

# Verify installations
docker --version         # If setup-docker.yml was run
kubectl version --client # If setup-k8s-kubeadm-sh.yml was run

# Exit and destroy VM
exit
vagrant destroy -f
```

### 1.3 Configure Ansible Vault (Secrets)

```bash
# Create vault password file
echo "your-secure-vault-password" > .vault_password
chmod 600 .vault_password

# Edit secret variables
ansible-vault edit ansible-secret-vars.yml

# Add your secrets (example):
# aws_access_key: "YOUR_AWS_ACCESS_KEY"
# aws_secret_key: "YOUR_AWS_SECRET_KEY"
# github_token: "YOUR_GITHUB_PAT"
```

## Phase 2: AWS Account Configuration

### 2.1 Configure AWS CLI

```bash
# Configure AWS credentials
aws configure

# Provide:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (us-east-1)
# - Default output format (json)

# Verify configuration
aws sts get-caller-identity
aws ec2 describe-regions --region us-east-1
```

### 2.2 Create AWS Resources for Terraform State

```bash
# Create S3 bucket for Terraform state (replace with unique name)
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2.3 Update Backend Configuration Files

Edit backend configuration files with your S3 bucket name:

```bash
# Edit envs/aws/backend-s3-nightly.conf
vim envs/aws/backend-s3-nightly.conf
```

```hcl
bucket         = "your-terraform-state-bucket"
key            = "nightly/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
```

Repeat for other environments:
- `backend-s3-qa.conf`
- `backend-s3-staging.conf`
- `backend-s3-prod.conf`

### 2.4 Create EC2 Key Pair

```bash
# Create or import SSH key pair
aws ec2 create-key-pair \
  --key-name cloud-automation-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/cloud-automation-key.pem

# Set permissions
chmod 400 ~/.ssh/cloud-automation-key.pem

# Add to SSH agent
ssh-add -K ~/.ssh/cloud-automation-key.pem
```

### 2.5 Update Configuration File

Edit `envs/aws/aws-config.yml` with your specific settings:

```bash
vim envs/aws/aws-config.yml
```

Update values:
- `key_name`: Your EC2 key pair name
- `your_ip`: Your current public IP (for SSH access)
- `ami_id`: Will be updated after Packer builds
- `github_repo`: Your forked repository URLs

## Phase 3: Build AMIs with Packer

### 3.1 Configure Packer Variables

```bash
# Copy template
cp ami/variables.pkrvars.hcl ami/variables.auto.pkrvars.hcl

# Edit with your values
vim ami/variables.auto.pkrvars.hcl
```

Example configuration:

```hcl
aws_region = "us-east-1"
instance_type = "t4g.nano"  # ARM64, use t3.nano for AMD64
ssh_username = "ubuntu"     # or "ec2-user" for Amazon Linux
source_ami_owner = "099720109477"  # Canonical for Ubuntu
```

### 3.2 Build Base AMI

```bash
# Validate Packer template
packer validate ami/setup-aws-base-image.pkr.hcl

# Build base AMI
packer build ami/setup-aws-base-image.pkr.hcl

# Note the AMI ID from output:
# ==> Builds finished. The artifacts of successful builds are:
# --> amazon-ebs.ubuntu-arm64: AMIs were created:
# us-east-1: ami-0123456789abcdef0
```

### 3.3 Update Variables for Subsequent Builds

Edit `ami/variables.auto.pkrvars.hcl` and set:

```hcl
base_ami_id = "ami-0123456789abcdef0"  # Your base AMI ID
```

### 3.4 Build Docker AMI

```bash
# Build Docker AMI (layered on base AMI)
packer build \
  -var-file=ami/variables.auto.pkrvars.hcl \
  ami/setup-aws-docker-image.pkr.hcl

# Note the Docker AMI ID
```

### 3.5 Build ECS AMI

```bash
# Update variables.auto.pkrvars.hcl with Docker AMI ID
vim ami/variables.auto.pkrvars.hcl
# docker_ami_id = "ami-xxxxxxxxx"

# Build ECS AMI
packer build \
  -var-file=ami/variables.auto.pkrvars.hcl \
  ami/setup-aws-ecr-ecs-image.pkr.hcl

# Note the ECS AMI ID
```

### 3.6 Build Containerd AMI (for Kubernetes)

```bash
# Build containerd AMI
packer build \
  -var-file=ami/variables.auto.pkrvars.hcl \
  ami/setup-aws-containerd-image.pkr.hcl

# Note the Containerd AMI ID
```

### 3.7 Update aws-config.yml with AMI IDs

```bash
vim envs/aws/aws-config.yml
```

Update the AMI IDs for your environment:

```yaml
environments:
  nightly:
    ami_id_base: "ami-base-xxxxx"
    ami_id_docker: "ami-docker-xxxxx"
    ami_id_ecs: "ami-ecs-xxxxx"
    ami_id_containerd: "ami-containerd-xxxxx"
```

## Phase 4: Infrastructure Provisioning

Deploy infrastructure in the following order. Each step builds upon the previous one.

### 4.1 Initialize Terraform State Backend

```bash
# Navigate to provider directory
cd envs/aws/infra/provider/nightly

# Initialize Terraform
terraform init -backend-config=../../backend-s3-nightly.conf

# Plan and apply
terraform plan
terraform apply

# Confirm with 'yes'
cd ../../../../..
```

### 4.2 Provision VPC

```bash
cd envs/aws/infra/vpc/nightly

# Initialize
terraform init -backend-config=../../backend-s3-nightly.conf

# Review plan
terraform plan

# Apply
terraform apply

# Note the VPC ID and subnet IDs from outputs
cd ../../../../..
```

### 4.3 Provision Security Groups

```bash
# Bastion host security group
cd envs/aws/infra/security-group/nightly/bastion-host
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

# ECS host security group
cd ../ecs-host-bridge-network
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

# External ALB security group
cd ../external-web-alb
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

# Internal host security group
cd ../internal-host
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

cd ../../../../../..
```

### 4.4 Provision IAM Roles and Policies

```bash
# EC2 IAM policy
cd envs/aws/infra/iam-policy/nightly/ec2-core
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

# EC2 IAM role
cd ../../iam-role/nightly/ec2-core
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

# ECS task execution role
cd ../ecs-task-execution
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

cd ../../../../../..
```

### 4.5 Provision SSM Document

```bash
cd envs/aws/infra/ssm-document/nightly/cloud-init-wait
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

cd ../../../../../..
```

### 4.6 Provision Bastion Host

```bash
cd envs/aws/infra/ec2-instances/nightly/bastion-host
terraform init -backend-config=../../../backend-s3-nightly.conf

# Plan
terraform plan

# Apply
terraform apply

# Note the bastion host public IP
cd ../../../../../..
```

### 4.7 Provision ECR Repositories

```bash
cd envs/aws/infra/ecr/nightly/ecr-repos
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

# Note the ECR repository URIs
cd ../../../../../..
```

### 4.8 Provision ECS Infrastructure

#### ECS Launch Template

```bash
cd envs/aws/infra/ecs/nightly/test-auto/launch_template
terraform init -backend-config=../../../../backend-s3-nightly.conf
terraform apply
cd ../../../../../../..
```

#### ECS Auto Scaling Group

```bash
cd envs/aws/infra/ecs/nightly/test-auto/asg
terraform init -backend-config=../../../../backend-s3-nightly.conf
terraform apply
cd ../../../../../../..
```

#### ECS Cluster

```bash
cd envs/aws/infra/ecs/nightly/test-auto/cluster
terraform init -backend-config=../../../../backend-s3-nightly.conf
terraform apply
cd ../../../../../../..
```

#### Application Load Balancer

```bash
cd envs/aws/infra/ecs/nightly/test-auto/alb
terraform init -backend-config=../../../../backend-s3-nightly.conf
terraform apply

# Note the ALB DNS name
cd ../../../../../../..
```

#### Target Groups

```bash
# Mock Email Service target group
cd envs/aws/infra/ecs/nightly/test-auto/target-group/mock-email-service
terraform init -backend-config=../../../../../backend-s3-nightly.conf
terraform apply

# Mock NASA API target group
cd ../mock-nasa-sound-api-service
terraform init -backend-config=../../../../../backend-s3-nightly.conf
terraform apply

cd ../../../../../../../..
```

#### HTTPS Listener (if using ACM)

```bash
cd envs/aws/infra/ecs/nightly/test-auto/alb-https
terraform init -backend-config=../../../../backend-s3-nightly.conf
terraform apply
cd ../../../../../../..
```

#### ALB Routing Rules

```bash
cd envs/aws/infra/ecs/nightly/test-auto/alb-rules
terraform init -backend-config=../../../../backend-s3-nightly.conf
terraform apply
cd ../../../../../../..
```

### 4.9 Provision Route53 and ACM (Optional)

```bash
# Hosted Zone
cd envs/aws/infra/route53/agilealm.click/hosted-zone
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

# ACM Certificate
cd ../mock-nasa-sound-api-acm
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

# Wait for ACM validation (may take a few minutes)
# Then create CNAME records

cd ../mock-email-service-cname
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

cd ../mock-nasa-sound-api-cname
terraform init -backend-config=../../../backend-s3-nightly.conf
terraform apply

cd ../../../../../../..
```

### 4.10 Provision GitHub Actions Self-Hosted Runners

```bash
# Mock Email Service runner
cd envs/aws/infra/ec2-instances/nightly/actions-runner/mock-email-service
terraform init -backend-config=../../../../backend-s3-nightly.conf
terraform apply

# Mock NASA API runner
cd ../mock-nasa-sound-api-service
terraform init -backend-config=../../../../backend-s3-nightly.conf
terraform apply

cd ../../../../../../..
```

## Phase 5: Application Deployment

### 5.1 Configure GitHub Actions Workflows

In your forked microservice repositories:

1. Update `.github/workflows/build-self-runner-arm64.yml`
2. Set the runner label to match your self-hosted runner
3. Update ECR repository URLs
4. Configure ECS cluster and service names

### 5.2 Deploy ECS Services

```bash
# Deploy Mock Email Service
cd envs/aws/app/mock-email-service/nightly/ecs
terraform init -backend-config=../../../../backend-s3-nightly.conf
terraform apply

# Deploy Mock NASA Sound API Service
cd ../../../mock-nasa-sound-api-service/nightly/ecs
terraform init -backend-config=../../../../backend-s3-nightly.conf
terraform apply

cd ../../../../../../..
```

### 5.3 Trigger GitHub Actions Builds

```bash
# Push a commit to your microservice repositories
# This will trigger the GitHub Actions workflow
# The self-hosted runner will:
# 1. Build the Java application
# 2. Create Docker image
# 3. Push to ECR
# 4. Update ECS service

# Monitor the workflow in GitHub Actions UI
```

### 5.4 Verify ECS Deployments

```bash
# List ECS services
aws ecs list-services --cluster your-cluster-name

# Describe service
aws ecs describe-services \
  --cluster your-cluster-name \
  --services mock-email-service

# Check running tasks
aws ecs list-tasks --cluster your-cluster-name

# View ALB targets
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

## Phase 6: Kubernetes Setup (Optional)

### 6.1 Provision Kubernetes Security Groups

```bash
# Control plane security group
cd envs/aws/infra/security-group/k8s-kubeadm-sh/cp-host
terraform init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf
terraform apply

# Data plane security group
cd ../dp-host
terraform init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf
terraform apply

cd ../../../../../..
```

### 6.2 Provision Control Plane Node

```bash
cd envs/aws/infra/k8s/kubeadm-sh/cp-node
terraform init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf
terraform plan
terraform apply

# Note: This will:
# 1. Launch EC2 instance with containerd AMI
# 2. Run Ansible playbook to initialize control plane
# 3. Store join token in ansible-vault

cd ../../../../../..
```

### 6.3 Provision Data Plane Nodes

```bash
# Data plane node 1
cd envs/aws/infra/k8s/kubeadm-sh/dp-node-1
terraform init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf
terraform apply

# Data plane node 2
cd ../dp-node-2
terraform init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf
terraform apply

cd ../../../../../..
```

### 6.4 Deploy Applications to Kubernetes

```bash
# SSH to control plane node via bastion
ssh -J ec2-user@<bastion-ip> ubuntu@<control-plane-ip>

# Apply manifests
kubectl apply -f /path/to/envs/aws/app/mock-email-service/k8s-kubeadm-sh/namespace.yaml
kubectl apply -f /path/to/envs/aws/app/mock-email-service/k8s-kubeadm-sh/deployment.yaml
kubectl apply -f /path/to/envs/aws/app/mock-email-service/k8s-kubeadm-sh/service.yaml

# Verify deployment
kubectl get pods -n mock-service
kubectl get svc -n mock-service
```

## Verification and Testing

### Verify ECS Deployment

```bash
# Get ALB DNS name
terraform -chdir=envs/aws/infra/ecs/nightly/test-auto/alb output alb_dns_name

# Test HTTP endpoint
curl http://<alb-dns-name>/mockemailservice/index.jsp

# Test HTTPS endpoint (if configured)
curl https://mockemailservice.agilealm.click/mockemailservice/index.jsp
```

### Verify Kubernetes Deployment

```bash
# SSH to control plane
ssh -J ec2-user@<bastion-ip> ubuntu@<control-plane-ip>

# Check cluster status
kubectl get nodes
kubectl get pods -A
kubectl get svc -n mock-service

# Get service LoadBalancer IP
kubectl get svc -n mock-service -o wide
```

### Verify GitHub Actions Runners

```bash
# SSH to runner instance
ssh -J ec2-user@<bastion-ip> ubuntu@<runner-ip>

# Check runner status
cd /home/ubuntu/actions-runner
./run.sh status
```

### Check AWS Resources

```bash
# List EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=nightly" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]' \
  --output table

# List ECS clusters
aws ecs list-clusters

# List ECR repositories
aws ecr describe-repositories
```

## Teardown

To destroy all resources and avoid ongoing AWS charges:

### Teardown Order (Reverse of Provisioning)

```bash
# 1. Destroy ECS services
terraform -chdir=envs/aws/app/mock-nasa-sound-api-service/nightly/ecs destroy
terraform -chdir=envs/aws/app/mock-email-service/nightly/ecs destroy

# 2. Destroy GitHub Actions runners
terraform -chdir=envs/aws/infra/ec2-instances/nightly/actions-runner/mock-nasa-sound-api-service destroy
terraform -chdir=envs/aws/infra/ec2-instances/nightly/actions-runner/mock-email-service destroy

# 3. Destroy Route53 and ACM
terraform -chdir=envs/aws/infra/route53/agilealm.click/mock-nasa-sound-api-cname destroy
terraform -chdir=envs/aws/infra/route53/agilealm.click/mock-email-service-cname destroy
terraform -chdir=envs/aws/infra/route53/agilealm.click/mock-nasa-sound-api-acm destroy
terraform -chdir=envs/aws/infra/route53/agilealm.click/hosted-zone destroy

# 4. Destroy ECS infrastructure
terraform -chdir=envs/aws/infra/ecs/nightly/test-auto/alb-rules destroy
terraform -chdir=envs/aws/infra/ecs/nightly/test-auto/alb-https destroy
terraform -chdir=envs/aws/infra/ecs/nightly/test-auto/target-group/mock-nasa-sound-api-service destroy
terraform -chdir=envs/aws/infra/ecs/nightly/test-auto/target-group/mock-email-service destroy
terraform -chdir=envs/aws/infra/ecs/nightly/test-auto/alb destroy
terraform -chdir=envs/aws/infra/ecs/nightly/test-auto/cluster destroy
terraform -chdir=envs/aws/infra/ecs/nightly/test-auto/asg destroy
terraform -chdir=envs/aws/infra/ecs/nightly/test-auto/launch_template destroy

# 5. Destroy ECR
terraform -chdir=envs/aws/infra/ecr/nightly/ecr-repos destroy

# 6. Destroy bastion host
terraform -chdir=envs/aws/infra/ec2-instances/nightly/bastion-host destroy

# 7. Destroy Kubernetes (if provisioned)
terraform -chdir=envs/aws/infra/k8s/kubeadm-sh/dp-node-2 destroy
terraform -chdir=envs/aws/infra/k8s/kubeadm-sh/dp-node-1 destroy
terraform -chdir=envs/aws/infra/k8s/kubeadm-sh/cp-node destroy
terraform -chdir=envs/aws/infra/security-group/k8s-kubeadm-sh/dp-host destroy
terraform -chdir=envs/aws/infra/security-group/k8s-kubeadm-sh/cp-host destroy

# 8. Destroy SSM document
terraform -chdir=envs/aws/infra/ssm-document/nightly/cloud-init-wait destroy

# 9. Destroy IAM roles and policies
terraform -chdir=envs/aws/infra/iam-role/nightly/ecs-task-execution destroy
terraform -chdir=envs/aws/infra/iam-role/nightly/ec2-core destroy
terraform -chdir=envs/aws/infra/iam-policy/nightly/ec2-core destroy

# 10. Destroy security groups
terraform -chdir=envs/aws/infra/security-group/nightly/internal-host destroy
terraform -chdir=envs/aws/infra/security-group/nightly/external-web-alb destroy
terraform -chdir=envs/aws/infra/security-group/nightly/ecs-host-bridge-network destroy
terraform -chdir=envs/aws/infra/security-group/nightly/bastion-host destroy

# 11. Destroy VPC
terraform -chdir=envs/aws/infra/vpc/nightly destroy

# 12. Destroy provider
terraform -chdir=envs/aws/infra/provider/nightly destroy

# 13. Deregister AMIs (manual)
aws ec2 deregister-image --image-id <ami-id>

# 14. Delete S3 state bucket (manual, after ensuring no state files needed)
# aws s3 rb s3://your-terraform-state-bucket --force
```

## Troubleshooting

### Packer Build Failures

**Issue**: Packer times out waiting for SSH

```bash
# Solution: Check security group allows SSH from your IP
# Increase timeout in Packer template
# Verify source AMI is correct
```

**Issue**: Ansible provisioner fails

```bash
# Enable Packer debug mode
export PACKER_LOG=1
packer build -debug ami/setup-aws-base-image.pkr.hcl

# Check Ansible syntax
ansible-playbook --syntax-check playbooks/setup-base-image.yml
```

### Terraform Apply Failures

**Issue**: Resource already exists

```bash
# Import existing resource
terraform import aws_instance.example i-1234567890abcdef0

# Or destroy and recreate
terraform destroy -target=aws_instance.example
terraform apply
```

**Issue**: State lock error

```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

**Issue**: Backend configuration error

```bash
# Reconfigure backend
terraform init -reconfigure -backend-config=backend-s3-nightly.conf
```

### ECS Service Issues

**Issue**: Tasks failing to start

```bash
# Check ECS task logs
aws logs tail /ecs/your-service --follow

# Describe stopped tasks
aws ecs describe-tasks \
  --cluster your-cluster \
  --tasks <task-arn>
```

**Issue**: ALB health checks failing

```bash
# Verify target group health
aws elbv2 describe-target-health --target-group-arn <arn>

# Check security group allows traffic from ALB
# Verify container port mapping is correct
```

### Kubernetes Issues

**Issue**: Nodes not joining cluster

```bash
# SSH to control plane
ssh -J ec2-user@<bastion-ip> ubuntu@<cp-ip>

# Check join token
kubeadm token list

# Regenerate token if expired
kubeadm token create --print-join-command

# SSH to data plane node and run join command
```

**Issue**: Pods not starting

```bash
# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check node resources
kubectl top nodes
kubectl describe node <node-name>
```

### Network Connectivity Issues

**Issue**: Cannot SSH to instances

```bash
# Verify security group rules
aws ec2 describe-security-groups --group-ids <sg-id>

# Check NACL rules
aws ec2 describe-network-acls --filters "Name=vpc-id,Values=<vpc-id>"

# Verify route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>"
```

**Issue**: Bastion host connection refused

```bash
# Verify instance is running
aws ec2 describe-instance-status --instance-id <instance-id>

# Check system log
aws ec2 get-console-output --instance-id <instance-id>

# Verify SSH key
ssh-add -l
```

### GitHub Actions Runner Issues

**Issue**: Runner not connecting

```bash
# SSH to runner instance
ssh -J ec2-user@<bastion-ip> ubuntu@<runner-ip>

# Check runner service
sudo systemctl status actions.runner.*

# Restart runner
cd /home/ubuntu/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh start

# Check logs
tail -f /home/ubuntu/actions-runner/_diag/*.log
```

## Support and Additional Resources

- **AWS Documentation**: https://docs.aws.amazon.com/
- **Terraform Registry**: https://registry.terraform.io/
- **Ansible Documentation**: https://docs.ansible.com/
- **Packer Documentation**: https://www.packer.io/docs
- **GitHub Actions**: https://docs.github.com/en/actions

For project-specific documentation:
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [docs/ANSIBLE.md](docs/ANSIBLE.md) - Ansible roles guide
- [docs/TERRAFORM.md](docs/TERRAFORM.md) - Terraform modules guide
- [docs/PACKER.md](docs/PACKER.md) - AMI building guide
- [docs/KUBERNETES.md](docs/KUBERNETES.md) - Kubernetes setup guide

---

**Deployment Complete!** You now have a fully functional cloud automation infrastructure on AWS.
