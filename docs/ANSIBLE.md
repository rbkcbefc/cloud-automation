# Ansible Documentation

This document provides comprehensive documentation for all Ansible roles and playbooks used in the Cloud Automation Framework.

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Configuration](#configuration)
- [Ansible Roles](#ansible-roles)
- [Ansible Playbooks](#playbooks)
- [Dynamic Inventory](#dynamic-inventory)
- [Secrets Management](#secrets-management)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

Ansible is used in this project for:
1. **Configuration Management** - Installing and configuring software on EC2 instances
2. **AMI Provisioning** - Used by Packer to build golden AMIs
3. **Post-Deployment Configuration** - Runtime configuration via Terraform local-exec
4. **Kubernetes Cluster Setup** - Initializing kubeadm-based Kubernetes clusters

## Directory Structure

```
cloud-automation/
├── ansible.cfg                    # Ansible configuration
├── ansible-secret-vars.yml        # Encrypted secrets (Ansible Vault)
├── group_vars/
│   └── all.yml                    # Global variables for all hosts
├── hosts.ini                      # Static inventory (local VMs)
├── hosts.aws_ec2.yml             # Dynamic inventory (AWS EC2)
├── roles/                         # Ansible roles (8 roles)
│   ├── basic_utils/
│   ├── docker/
│   ├── containerd/
│   ├── ecr-helper/
│   ├── ecs-agent/
│   ├── aws-ssm-agent/
│   ├── setup-actions-runner/
│   └── k8s-kubeadm-sh/
└── playbooks/                     # Ansible playbooks (10 playbooks)
    ├── setup-base-image.yml
    ├── setup-docker.yml
    ├── setup-containerd.yml
    ├── setup-aws-ecs-agent.yml
    ├── setup-aws-ecr-helper.yml
    ├── setup-aws-ecr-ecs.yml
    ├── setup-actions-runner.yml
    ├── setup-aws-ssm-agent.yml
    ├── setup-k8s-kubeadm-sh.yml
    └── verify-connectivity.yml
```

## Configuration

### ansible.cfg

```ini
[defaults]
inventory = hosts.ini
roles_path = roles
vault_password_file = .vault_password
log_path = /var/log/ansible.log
forks = 20
host_key_checking = False
retry_files_enabled = False
```

**Key Settings**:
- `inventory`: Default inventory file (can be overridden with `-i`)
- `roles_path`: Location of Ansible roles
- `vault_password_file`: Password file for Ansible Vault
- `forks`: Number of parallel executions (default: 20)
- `host_key_checking`: Disabled for AWS dynamic instances

### group_vars/all.yml

Global variables accessible to all hosts and roles:

```yaml
# Example variables (customize as needed)
ansible_user: ubuntu
ansible_ssh_private_key_file: ~/.ssh/cloud-automation-key.pem
```

## Ansible Roles

### 1. basic_utils

**Purpose**: Install common system utilities and packages

**Location**: `roles/basic_utils/`

**Supported OS**:
- Ubuntu/Debian
- CentOS/RHEL
- Amazon Linux 2023

**Installed Packages**:
- `git` - Version control
- `curl`, `wget` - HTTP clients
- `vim`, `nano` - Text editors
- `htop` - Process monitor
- `net-tools` - Network utilities
- `jq` - JSON processor
- `unzip`, `zip` - Archive utilities
- `tree` - Directory tree viewer

**Directory Structure**:
```
basic_utils/
├── defaults/
│   └── main.yml              # Default variables
├── handlers/
│   └── main.yml              # Handlers (if any)
├── meta/
│   └── main.yml              # Role metadata
├── tasks/
│   ├── main.yml              # Main task entry point
│   ├── configure-debian.yml  # Debian/Ubuntu specific tasks
│   ├── configure-redhat-centos.yml  # CentOS/RHEL tasks
│   └── configure-redhat-al2023.yml  # Amazon Linux 2023 tasks
├── templates/
│   └── (Jinja2 templates)
└── vars/
    └── main.yml              # Role variables
```

**Usage**:
```yaml
- hosts: all
  roles:
    - basic_utils
```

**Variables**:
```yaml
# defaults/main.yml
basic_packages_debian:
  - git
  - curl
  - wget
  - vim
  - htop

basic_packages_redhat:
  - git
  - curl
  - wget
  - vim
  - htop
```

---

### 2. docker

**Purpose**: Install and configure Docker CE (Community Edition)

**Location**: `roles/docker/`

**Supported OS**:
- Ubuntu/Debian
- CentOS/RHEL
- Amazon Linux 2023

**Features**:
- Installs Docker CE from official repositories
- Configures Docker daemon options
- Sets up overlay2 storage driver
- Adds user to docker group
- Enables Docker service on boot

**Directory Structure**:
```
docker/
├── defaults/
│   └── main.yml
├── handlers/
│   └── main.yml              # Restart docker service
├── tasks/
│   ├── main.yml
│   ├── configure-debian.yml
│   ├── configure-redhat-centos.yml
│   ├── configure-redhat-al2023.yml
│   └── docker-post-install-debian.yml
│   └── docker-post-install-redhat.yml
├── templates/
│   └── daemon.json.j2        # Docker daemon configuration
└── vars/
    └── main.yml
```

**Configuration**:

`templates/daemon.json.j2`:
```json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

**Post-Install Tasks**:
- Add user to docker group: `usermod -aG docker $USER`
- Enable Docker service: `systemctl enable docker`
- Start Docker service: `systemctl start docker`

**Usage**:
```yaml
- hosts: docker_hosts
  become: yes
  roles:
    - docker
```

**Verification**:
```bash
docker --version
docker run hello-world
```

---

### 3. containerd

**Purpose**: Install and configure containerd container runtime (for Kubernetes)

**Location**: `roles/containerd/`

**Components Installed**:
- **containerd** - Container runtime
- **runc** - OCI runtime
- **crictl** - Container runtime interface CLI

**Directory Structure**:
```
containerd/
├── defaults/
│   └── main.yml              # containerd version, download URLs
├── tasks/
│   ├── main.yml
│   ├── install-containerd.yml
│   ├── configure-containerd.yml
│   └── verify-installation.yml
├── templates/
│   └── config.toml.j2        # containerd configuration
└── handlers/
    └── main.yml              # Restart containerd service
```

**Installed Versions** (example):
```yaml
# defaults/main.yml
containerd_version: "1.7.13"
runc_version: "1.1.12"
crictl_version: "1.29.0"
```

**Configuration**:

`templates/config.toml.j2`:
```toml
version = 2

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
```

**Tasks**:
1. Download and install containerd, runc, crictl
2. Generate default containerd config
3. Enable systemd cgroup driver
4. Start and enable containerd service
5. Verify installation with `crictl ps`

**Usage**:
```yaml
- hosts: k8s_nodes
  become: yes
  roles:
    - containerd
```

**Verification**:
```bash
containerd --version
runc --version
crictl --version
crictl ps
```

---

### 4. ecr-helper

**Purpose**: Install AWS ECR credential helper for Docker

**Location**: `roles/ecr-helper/`

**Features**:
- Downloads and installs `amazon-ecr-credential-helper`
- Configures Docker to use ECR helper for authentication
- Enables automatic ECR login

**Directory Structure**:
```
ecr-helper/
├── defaults/
│   └── main.yml              # ECR helper version
├── tasks/
│   ├── main.yml
│   ├── configure-debian.yml
│   └── configure-redhat.yml
└── templates/
    └── config.json.j2        # Docker config for ECR
```

**Configuration**:

`templates/config.json.j2`:
```json
{
  "credsStore": "ecr-login"
}
```

**Installation Path**: `/usr/local/bin/docker-credential-ecr-login`

**Usage**:
```yaml
- hosts: ecs_hosts
  become: yes
  roles:
    - docker
    - ecr-helper
```

**Verification**:
```bash
docker-credential-ecr-login -v
docker pull <account-id>.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest
```

---

### 5. ecs-agent

**Purpose**: Install and configure AWS ECS agent

**Location**: `roles/ecs-agent/`

**Features**:
- Downloads and installs ECS agent
- Configures ECS cluster registration
- Sets up systemd service for ECS agent

**Directory Structure**:
```
ecs-agent/
├── defaults/
│   └── main.yml              # ECS cluster name, region
├── tasks/
│   ├── main.yml
│   ├── configure-debian.yml
│   └── configure-redhat.yml
├── templates/
│   └── ecs.service.j2        # systemd service file
└── handlers/
    └── main.yml              # Restart ECS agent
```

**Configuration**:

`templates/ecs.service.j2`:
```ini
[Unit]
Description=AWS ECS Agent
After=docker.service
Requires=docker.service

[Service]
Environment="ECS_CLUSTER={{ ecs_cluster_name }}"
Environment="ECS_DATADIR=/var/lib/ecs/data"
ExecStart=/usr/bin/docker run --name ecs-agent \
  --env ECS_CLUSTER={{ ecs_cluster_name }} \
  --volume=/var/run:/var/run \
  --volume=/var/log/ecs:/log \
  --volume=/var/lib/ecs/data:/data \
  --net=host \
  --restart=on-failure:10 \
  amazon/amazon-ecs-agent:latest

[Install]
WantedBy=multi-user.target
```

**Variables**:
```yaml
# defaults/main.yml
ecs_cluster_name: "my-ecs-cluster"
aws_region: "us-east-1"
```

**Usage**:
```yaml
- hosts: ecs_hosts
  become: yes
  vars:
    ecs_cluster_name: "production-cluster"
  roles:
    - docker
    - ecr-helper
    - ecs-agent
```

**Verification**:
```bash
systemctl status ecs
docker ps | grep ecs-agent
aws ecs list-container-instances --cluster my-ecs-cluster
```

---

### 6. aws-ssm-agent

**Purpose**: Install AWS Systems Manager Session Manager agent

**Location**: `roles/aws-ssm-agent/`

**Features**:
- Installs SSM agent for secure shell access
- Enables browser-based shell sessions
- No need to open SSH ports or manage SSH keys

**Directory Structure**:
```
aws-ssm-agent/
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml
│   ├── pre-tasks-debian.yml
│   ├── pre-tasks-redhat.yml
│   ├── configure-debian.yml
│   └── configure-redhat.yml
└── handlers/
    └── main.yml              # Restart ssm agent
```

**Usage**:
```yaml
- hosts: all
  become: yes
  roles:
    - aws-ssm-agent
```

**Verification**:
```bash
systemctl status amazon-ssm-agent
aws ssm start-session --target i-1234567890abcdef0
```

---

### 7. setup-actions-runner

**Purpose**: Install and configure GitHub Actions self-hosted runner

**Location**: `roles/setup-actions-runner/`

**Features**:
- Downloads latest GitHub Actions runner
- Registers runner with GitHub repository
- Configures runner as systemd service
- Supports labels and runner groups

**Directory Structure**:
```
setup-actions-runner/
├── defaults/
│   └── main.yml              # GitHub repo, token, labels
├── tasks/
│   ├── main.yml
│   ├── download-runner.yml
│   ├── configure-runner.yml
│   └── install-service.yml
└── handlers/
    └── main.yml              # Restart runner service
```

**Variables**:
```yaml
# defaults/main.yml
github_repo: "https://github.com/owner/repo"
github_token: "{{ vault_github_token }}"
runner_name: "self-hosted-runner-1"
runner_labels: "self-hosted,linux,arm64"
runner_group: "Default"
```

**Installation Steps**:
1. Create runner user
2. Download runner package from GitHub
3. Extract to `/home/ubuntu/actions-runner/`
4. Run `./config.sh` with token
5. Install as service: `./svc.sh install`
6. Start service: `./svc.sh start`

**Usage**:
```yaml
- hosts: runner_hosts
  become: yes
  vars:
    github_repo: "https://github.com/myorg/myrepo"
    github_token: "{{ vault_github_token }}"
    runner_labels: "self-hosted,linux,arm64,java"
  roles:
    - basic_utils
    - docker
    - setup-actions-runner
```

**Verification**:
```bash
cd /home/ubuntu/actions-runner
./run.sh status
sudo systemctl status actions.runner.*
```

---

### 8. k8s-kubeadm-sh

**Purpose**: Initialize Kubernetes cluster using kubeadm

**Location**: `roles/k8s-kubeadm-sh/`

**Features**:
- Installs kubeadm, kubelet, kubectl
- Initializes control plane or joins worker nodes
- Installs Calico CNI
- Stores join tokens in Ansible Vault

**Directory Structure**:
```
k8s-kubeadm-sh/
├── defaults/
│   └── main.yml              # Kubernetes version, pod CIDR
├── tasks/
│   ├── main.yml
│   ├── configure-debian.yml
│   ├── init-control-plane.yml
│   ├── join-data-plane.yml
│   └── install-calico.yml
├── templates/
│   ├── kubeadm-config.yaml.j2
│   └── calico.yaml.j2
└── vars/
    └── main.yml
```

**Variables**:
```yaml
# defaults/main.yml
k8s_version: "1.29"
pod_network_cidr: "192.168.0.0/16"
service_cidr: "10.96.0.0/12"
k8s_node_role: "control-plane"  # or "data-plane"
```

**Control Plane Initialization**:
```bash
kubeadm init --config /tmp/kubeadm-config.yaml
kubectl apply -f /tmp/calico.yaml
```

**Join Command**:
```bash
kubeadm join <control-plane-ip>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

**Usage**:

Control Plane:
```yaml
- hosts: k8s_control_plane
  become: yes
  vars:
    k8s_node_role: "control-plane"
  roles:
    - containerd
    - k8s-kubeadm-sh
```

Data Plane:
```yaml
- hosts: k8s_data_plane
  become: yes
  vars:
    k8s_node_role: "data-plane"
    k8s_join_token: "{{ vault_k8s_join_token }}"
    k8s_discovery_token_hash: "{{ vault_k8s_discovery_hash }}"
  roles:
    - containerd
    - k8s-kubeadm-sh
```

**Verification**:
```bash
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

---

## Playbooks

### 1. setup-base-image.yml

**Purpose**: Create base AMI with common utilities

**Location**: `playbooks/setup-base-image.yml`

**Roles Used**:
- `basic_utils`

**Execution**:
```bash
ansible-playbook playbooks/setup-base-image.yml
```

**Used By**: Packer template `ami/setup-aws-base-image.pkr.hcl`

---

### 2. setup-docker.yml

**Purpose**: Install Docker CE

**Location**: `playbooks/setup-docker.yml`

**Roles Used**:
- `docker`

**Execution**:
```bash
ansible-playbook playbooks/setup-docker.yml
```

**Used By**: Packer template `ami/setup-aws-docker-image.pkr.hcl`

---

### 3. setup-containerd.yml

**Purpose**: Install containerd runtime

**Location**: `playbooks/setup-containerd.yml`

**Roles Used**:
- `containerd`

**Execution**:
```bash
ansible-playbook playbooks/setup-containerd.yml
```

**Used By**: Packer template `ami/setup-aws-containerd-image.pkr.hcl`

---

### 4. setup-aws-ecs-agent.yml

**Purpose**: Install ECS agent

**Location**: `playbooks/setup-aws-ecs-agent.yml`

**Roles Used**:
- `ecs-agent`

**Execution**:
```bash
ansible-playbook playbooks/setup-aws-ecs-agent.yml
```

**Used By**: Packer template `ami/setup-aws-ecs-agent-image.pkr.hcl`

---

### 5. setup-aws-ecr-helper.yml

**Purpose**: Install ECR credential helper

**Location**: `playbooks/setup-aws-ecr-helper.yml`

**Roles Used**:
- `ecr-helper`

**Execution**:
```bash
ansible-playbook playbooks/setup-aws-ecr-helper.yml
```

**Used By**: Packer template `ami/setup-aws-ecr-helper-image.pkr.hcl`

---

### 6. setup-aws-ecr-ecs.yml

**Purpose**: Install both ECR helper and ECS agent

**Location**: `playbooks/setup-aws-ecr-ecs.yml`

**Roles Used**:
- `ecr-helper`
- `ecs-agent`

**Execution**:
```bash
ansible-playbook playbooks/setup-aws-ecr-ecs.yml
```

**Used By**: Packer template `ami/setup-aws-ecr-ecs-image.pkr.hcl`

---

### 7. setup-actions-runner.yml

**Purpose**: Configure GitHub Actions self-hosted runner

**Location**: `playbooks/setup-actions-runner.yml`

**Roles Used**:
- `setup-actions-runner`

**Execution**:
```bash
ansible-playbook playbooks/setup-actions-runner.yml \
  -e "github_repo=https://github.com/myorg/myrepo" \
  -e "github_token=ghp_xxx"
```

**Used By**: Terraform local-exec provisioner or manual deployment

---

### 8. setup-aws-ssm-agent.yml

**Purpose**: Install SSM Session Manager agent

**Location**: `playbooks/setup-aws-ssm-agent.yml`

**Roles Used**:
- `aws-ssm-agent`

**Execution**:
```bash
ansible-playbook playbooks/setup-aws-ssm-agent.yml
```

---

### 9. setup-k8s-kubeadm-sh.yml

**Purpose**: Initialize Kubernetes cluster

**Location**: `playbooks/setup-k8s-kubeadm-sh.yml`

**Roles Used**:
- `k8s-kubeadm-sh`

**Execution**:

Control Plane:
```bash
ansible-playbook playbooks/setup-k8s-kubeadm-sh.yml \
  -e "k8s_node_role=control-plane" \
  -i hosts.aws_ec2.yml \
  --limit k8s_control_plane
```

Data Plane:
```bash
ansible-playbook playbooks/setup-k8s-kubeadm-sh.yml \
  -e "k8s_node_role=data-plane" \
  -i hosts.aws_ec2.yml \
  --limit k8s_data_plane
```

---

### 10. verify-connectivity.yml

**Purpose**: Test connectivity to target hosts

**Location**: `playbooks/verify-connectivity.yml`

**Tasks**:
- Ping all hosts
- Gather facts
- Display host information

**Execution**:
```bash
ansible-playbook playbooks/verify-connectivity.yml
```

---

## Dynamic Inventory

### AWS EC2 Dynamic Inventory

**File**: `hosts.aws_ec2.yml`

**Purpose**: Automatically discover and group EC2 instances

**Configuration**:
```yaml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  instance-state-name: running
keyed_groups:
  - key: tags.Environment
    prefix: env
  - key: tags.Role
    prefix: role
hostnames:
  - private-ip-address
compose:
  ansible_host: public_ip_address
```

**Usage**:
```bash
# List inventory
ansible-inventory -i hosts.aws_ec2.yml --list

# Run playbook with dynamic inventory
ansible-playbook -i hosts.aws_ec2.yml playbooks/setup-docker.yml
```

**Grouping Examples**:
- `env_nightly` - All instances tagged with Environment=nightly
- `role_bastion` - All instances tagged with Role=bastion
- `role_ecs` - All instances tagged with Role=ecs

---

## Secrets Management

### Ansible Vault

**File**: `ansible-secret-vars.yml`

**Create Vault**:
```bash
# Create vault password file
echo "your-secure-password" > .vault_password
chmod 600 .vault_password

# Create encrypted file
ansible-vault create ansible-secret-vars.yml
```

**Edit Vault**:
```bash
ansible-vault edit ansible-secret-vars.yml
```

**View Vault**:
```bash
ansible-vault view ansible-secret-vars.yml
```

**Encrypt Existing File**:
```bash
ansible-vault encrypt ansible-secret-vars.yml
```

**Decrypt File**:
```bash
ansible-vault decrypt ansible-secret-vars.yml
```

**Example Secrets**:
```yaml
# ansible-secret-vars.yml
vault_github_token: "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
vault_aws_access_key: "AKIAIOSFODNN7EXAMPLE"
vault_aws_secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
vault_k8s_join_token: "abcdef.0123456789abcdef"
vault_k8s_discovery_hash: "sha256:xxxxx"
```

**Using Secrets in Playbooks**:
```yaml
- hosts: all
  vars_files:
    - ansible-secret-vars.yml
  tasks:
    - name: Use GitHub token
      debug:
        msg: "{{ vault_github_token }}"
```

---

## Best Practices

### 1. Role Organization

- Keep roles focused and single-purpose
- Use `defaults/main.yml` for default values
- Use `vars/main.yml` for non-overridable values
- Document all variables in README

### 2. Idempotency

- Ensure tasks can run multiple times safely
- Use `creates` parameter for command tasks
- Check for file/package existence before installation

Example:
```yaml
- name: Download file
  get_url:
    url: "https://example.com/file.tar.gz"
    dest: "/tmp/file.tar.gz"
    checksum: "sha256:xxxxx"
  creates: "/tmp/file.tar.gz"
```

### 3. Error Handling

- Use `failed_when` for custom failure conditions
- Use `ignore_errors` sparingly
- Add `block/rescue` for complex error handling

Example:
```yaml
- block:
    - name: Risky task
      command: /bin/risky-command
  rescue:
    - name: Handle error
      debug:
        msg: "Command failed, but continuing"
```

### 4. Testing

- Test roles locally with Vagrant before deploying
- Use `--check` mode for dry runs
- Use `--diff` to see changes

```bash
ansible-playbook playbooks/setup-docker.yml --check --diff
```

### 5. Variable Precedence

Understand Ansible variable precedence (lowest to highest):
1. role defaults
2. inventory vars
3. playbook vars
4. extra vars (`-e`)

### 6. Handlers

- Use handlers for service restarts
- Notify handlers from tasks
- Handlers run at the end of the play

Example:
```yaml
# tasks/main.yml
- name: Update Docker config
  template:
    src: daemon.json.j2
    dest: /etc/docker/daemon.json
  notify: restart docker

# handlers/main.yml
- name: restart docker
  service:
    name: docker
    state: restarted
```

---

## Troubleshooting

### Connection Issues

**Problem**: Cannot connect to hosts

```bash
# Test connectivity
ansible all -m ping -i hosts.aws_ec2.yml

# Check SSH
ssh -i ~/.ssh/cloud-automation-key.pem ubuntu@<host-ip>

# Verbose mode
ansible-playbook playbooks/setup-docker.yml -vvv
```

### Permission Issues

**Problem**: Permission denied errors

```bash
# Ensure become (sudo) is used
ansible-playbook playbooks/setup-docker.yml --become

# Check SSH key permissions
chmod 400 ~/.ssh/cloud-automation-key.pem
```

### Vault Issues

**Problem**: Cannot decrypt vault

```bash
# Verify vault password file
cat .vault_password

# Manually provide password
ansible-playbook playbooks/setup-docker.yml --ask-vault-pass
```

### Role Not Found

**Problem**: Role 'xxx' was not found

```bash
# Check roles_path in ansible.cfg
grep roles_path ansible.cfg

# Verify role exists
ls -la roles/
```

### Dynamic Inventory Issues

**Problem**: AWS EC2 inventory returns no hosts

```bash
# Test inventory
ansible-inventory -i hosts.aws_ec2.yml --list

# Check AWS credentials
aws ec2 describe-instances

# Verify boto3 is installed
pip3 install boto3 botocore
```

---

## Summary

This Ansible setup provides:
- **8 reusable roles** for different components
- **10 playbooks** for various deployment scenarios
- **Dynamic inventory** for AWS EC2 auto-discovery
- **Secrets management** with Ansible Vault
- **Multi-OS support** (Ubuntu, CentOS, Amazon Linux)
- **Integration with Packer and Terraform**

For more information, see the main [README.md](../README.md) and [DEPLOYMENT.md](../DEPLOYMENT.md).
