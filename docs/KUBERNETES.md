# Kubernetes Documentation

This document provides comprehensive documentation for setting up and managing a self-hosted Kubernetes cluster using kubeadm on AWS.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Components](#components)
- [Deployment Process](#deployment-process)
- [Cluster Operations](#cluster-operations)
- [Application Deployment](#application-deployment)
- [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
- [Networking](#networking)
- [Storage](#storage)
- [Security](#security)
- [Upgrading](#upgrading)

## Overview

This project includes a self-hosted Kubernetes cluster provisioned on AWS using **kubeadm**, **containerd** as the container runtime, and **Calico** for networking.

**Cluster Configuration**:
- **1 Control Plane Node** - Manages the cluster
- **2 Data Plane Nodes** - Worker nodes running application workloads
- **Container Runtime**: containerd
- **CNI**: Calico
- **Kubernetes Version**: 1.29+

**Deployment Tools**:
- **Packer**: Build containerd AMI
- **Terraform**: Provision EC2 instances
- **Ansible**: Initialize Kubernetes cluster
- **kubeadm**: Bootstrap Kubernetes components

## Architecture

### Cluster Design

```
┌──────────────────────────────────────────────────────────────┐
│                         AWS VPC                               │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Public Subnet (10.0.1.0/24)                            │  │
│  │                                                         │  │
│  │  ┌──────────────────────────────────────────────────┐ │  │
│  │  │ Control Plane Node                               │ │  │
│  │  │ - kube-apiserver (port 6443)                     │ │  │
│  │  │ - kube-controller-manager                        │ │  │
│  │  │ - kube-scheduler                                 │ │  │
│  │  │ - etcd                                           │ │  │
│  │  │ - kubelet                                        │ │  │
│  │  │ - Calico CNI                                     │ │  │
│  │  │ - Public IP: accessible for kubectl              │ │  │
│  │  └──────────────────────────────────────────────────┘ │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Private Subnet (10.0.3.0/24)                           │  │
│  │                                                         │  │
│  │  ┌──────────────────────┐  ┌──────────────────────┐  │  │
│  │  │ Data Plane Node 1    │  │ Data Plane Node 2    │  │  │
│  │  │ - kubelet            │  │ - kubelet            │  │  │
│  │  │ - kube-proxy         │  │ - kube-proxy         │  │  │
│  │  │ - containerd         │  │ - containerd         │  │  │
│  │  │ - Calico agent       │  │ - Calico agent       │  │  │
│  │  │ - Application Pods   │  │ - Application Pods   │  │  │
│  │  │ - Private IP only    │  │ - Private IP only    │  │  │
│  │  └──────────────────────┘  └──────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  Access: Bastion Host → SSH → Control Plane/Data Plane      │
└──────────────────────────────────────────────────────────────┘
```

### Network Architecture

**Control Plane**:
- Located in **public subnet**
- API Server accessible on **port 6443**
- Public IP for kubectl access
- Communicates with data plane nodes via private IPs

**Data Plane Nodes**:
- Located in **private subnet**
- No public IPs
- Access via bastion host
- Communicate with control plane via private network

**Pod Network**:
- **CIDR**: 192.168.0.0/16 (Calico default)
- **Service CIDR**: 10.96.0.0/12 (Kubernetes default)

## Prerequisites

### AWS Resources

Ensure the following are provisioned:
- VPC with public and private subnets
- Security groups (control plane and data plane)
- IAM roles for EC2 instances
- Bastion host for SSH access
- Containerd AMI built with Packer

### Local Tools

```bash
# Required on your local machine
kubectl version --client  # >= 1.29
ssh -V                    # SSH client
aws --version            # AWS CLI
```

### Configuration Files

```
envs/aws/config/k8s-kubeadm-sh.yml
envs/aws/infra/k8s/kubeadm-sh/
├── cp-node/main.tf
├── dp-node-1/main.tf
└── dp-node-2/main.tf
```

## Components

### 1. Container Runtime: containerd

**Installation**: Via Ansible role `containerd`

**Configuration** (`/etc/containerd/config.toml`):
```toml
version = 2

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
```

**Verification**:
```bash
sudo systemctl status containerd
sudo crictl ps
```

### 2. kubeadm, kubelet, kubectl

**Installation**: Via Ansible role `k8s-kubeadm-sh`

**Packages**:
- `kubeadm` - Bootstrap tool
- `kubelet` - Node agent
- `kubectl` - CLI tool

**Version**: 1.29+

**Configuration**:
```yaml
# /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
```

### 3. Calico CNI

**Version**: v3.27+

**Purpose**: Pod networking

**Installation**: Applied during control plane initialization

**Manifest**: Downloaded from Calico GitHub

**Configuration**:
- Pod CIDR: 192.168.0.0/16
- IPIP encapsulation enabled
- BGP peering for network policy

**Verification**:
```bash
kubectl get pods -n kube-system | grep calico
kubectl get nodes  # Should show Ready status
```

### 4. etcd

**Type**: Stacked etcd (runs on control plane)

**Data Directory**: `/var/lib/etcd`

**Backup**: Should be automated (future enhancement)

**Verification**:
```bash
sudo crictl ps | grep etcd
kubectl -n kube-system get pods | grep etcd
```

## Deployment Process

### Step 1: Build Containerd AMI

```bash
# Build base AMI first
packer build ami/setup-aws-base-image.pkr.hcl

# Build containerd AMI
packer build -var-file=ami/variables.auto.pkrvars.hcl ami/setup-aws-containerd-image.pkr.hcl

# Note the AMI ID
# Example: ami-containerd-xxxxx
```

### Step 2: Update Configuration

Edit `envs/aws/config/k8s-kubeadm-sh.yml`:

```yaml
kubernetes:
  version: "1.29"
  pod_network_cidr: "192.168.0.0/16"
  service_cidr: "10.96.0.0/12"

aws:
  region: "us-east-1"
  ami_id: "ami-containerd-xxxxx"  # From Packer build
  instance_type_cp: "t4g.medium"
  instance_type_dp: "t4g.small"
  key_name: "cloud-automation-key"

network:
  vpc_id: "vpc-xxxxx"
  public_subnet_id: "subnet-pub-xxxxx"
  private_subnet_ids:
    - "subnet-priv-1-xxxxx"
    - "subnet-priv-2-xxxxx"
```

### Step 3: Provision Security Groups

```bash
# Control Plane Security Group
cd envs/aws/infra/security-group/k8s-kubeadm-sh/cp-host
terraform init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf
terraform apply

# Data Plane Security Group
cd ../dp-host
terraform init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf
terraform apply
```

**Control Plane Inbound Rules**:
- TCP 6443 from 0.0.0.0/0 (API server)
- TCP 2379-2380 from data plane (etcd)
- TCP 10250 from data plane (kubelet)
- TCP 22 from bastion (SSH)

**Data Plane Inbound Rules**:
- TCP 10250 from control plane (kubelet)
- TCP 30000-32767 from control plane (NodePort services)
- TCP 22 from bastion (SSH)

### Step 4: Provision Control Plane Node

```bash
cd envs/aws/infra/k8s/kubeadm-sh/cp-node
terraform init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf
terraform plan
terraform apply
```

**What Terraform Does**:
1. Launch EC2 instance in public subnet
2. Assign public IP and elastic IP (optional)
3. Wait for cloud-init to complete
4. Run Ansible playbook via local-exec
5. Initialize control plane with kubeadm
6. Install Calico CNI
7. Store join token in Ansible Vault

**Ansible Tasks** (via `playbooks/setup-k8s-kubeadm-sh.yml`):
```yaml
- name: Initialize Kubernetes control plane
  command: |
    kubeadm init \
      --pod-network-cidr=192.168.0.0/16 \
      --service-cidr=10.96.0.0/12 \
      --apiserver-advertise-address={{ ansible_default_ipv4.address }}

- name: Create .kube directory
  file:
    path: /home/ubuntu/.kube
    state: directory

- name: Copy kubeconfig
  copy:
    src: /etc/kubernetes/admin.conf
    dest: /home/ubuntu/.kube/config
    remote_src: yes
    owner: ubuntu

- name: Install Calico CNI
  command: kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

- name: Generate join command
  command: kubeadm token create --print-join-command
  register: join_command

- name: Save join token to Ansible Vault
  local_action:
    module: shell
    cmd: |
      ansible-vault encrypt_string '{{ join_command.stdout }}' \
        --name 'k8s_join_command' >> ansible-secret-vars.yml
```

### Step 5: Retrieve Kubeconfig

```bash
# SSH to control plane via bastion
ssh -J ec2-user@<bastion-ip> ubuntu@<control-plane-ip>

# Copy kubeconfig content
cat ~/.kube/config

# On your local machine
mkdir -p ~/.kube
vim ~/.kube/config-k8s-aws
# Paste the content

# Set KUBECONFIG
export KUBECONFIG=~/.kube/config-k8s-aws

# Test connection
kubectl get nodes
```

### Step 6: Provision Data Plane Node 1

```bash
cd envs/aws/infra/k8s/kubeadm-sh/dp-node-1
terraform init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf
terraform apply
```

**What Terraform Does**:
1. Launch EC2 instance in private subnet
2. Run Ansible playbook to join cluster
3. Uses join token from Ansible Vault

**Ansible Tasks**:
```yaml
- name: Join Kubernetes cluster
  command: "{{ k8s_join_command }}"
  args:
    creates: /etc/kubernetes/kubelet.conf
```

### Step 7: Provision Data Plane Node 2

```bash
cd ../dp-node-2
terraform init -backend-config=../../../config/backend-s3-k8s-kubeadm-sh.conf
terraform apply
```

### Step 8: Verify Cluster

```bash
# Check nodes
kubectl get nodes

# Expected output:
# NAME                       STATUS   ROLES           AGE   VERSION
# ip-10-0-1-10.ec2.internal  Ready    control-plane   10m   v1.29.0
# ip-10-0-3-20.ec2.internal  Ready    <none>          5m    v1.29.0
# ip-10-0-3-21.ec2.internal  Ready    <none>          5m    v1.29.0

# Check pods
kubectl get pods -A

# Check Calico
kubectl get pods -n kube-system | grep calico
```

## Cluster Operations

### Access Control Plane

```bash
# Via bastion host
ssh -J ec2-user@<bastion-ip> ubuntu@<control-plane-ip>

# Check cluster status
kubectl cluster-info
kubectl get componentstatuses
```

### Access Data Plane Nodes

```bash
# SSH via bastion
ssh -J ec2-user@<bastion-ip> ubuntu@<data-plane-ip>

# Check kubelet status
sudo systemctl status kubelet

# Check containerd
sudo crictl ps
sudo crictl pods
```

### Add New Worker Node

```bash
# On control plane, generate new join token
ssh -J ec2-user@<bastion-ip> ubuntu@<control-plane-ip>
kubeadm token create --print-join-command

# Copy the join command
# Example:
# kubeadm join 10.0.1.10:6443 --token abc123.xyz789 \
#   --discovery-token-ca-cert-hash sha256:xxxxx

# On new worker node
sudo kubeadm join 10.0.1.10:6443 --token abc123.xyz789 \
  --discovery-token-ca-cert-hash sha256:xxxxx

# Verify from control plane
kubectl get nodes
```

### Remove Worker Node

```bash
# Drain the node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Delete the node
kubectl delete node <node-name>

# On the worker node
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/kubelet
sudo rm -rf /etc/kubernetes
```

### kubeconfig Management

```bash
# View current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>

# Set namespace
kubectl config set-context --current --namespace=<namespace>
```

## Application Deployment

### Deploy Example Application

Manifests location: `envs/aws/app/mock-email-service/k8s-kubeadm-sh/`

**1. Create Namespace**:
```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mock-service
```

```bash
kubectl apply -f namespace.yaml
```

**2. Create Deployment**:
```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mock-email-service
  namespace: mock-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mock-email-service
  template:
    metadata:
      labels:
        app: mock-email-service
    spec:
      containers:
      - name: mock-email-service
        image: <account-id>.dkr.ecr.us-east-1.amazonaws.com/mock-email-service:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

```bash
kubectl apply -f deployment.yaml
```

**3. Create Service**:
```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mock-email-service
  namespace: mock-service
spec:
  selector:
    app: mock-email-service
  type: LoadBalancer
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
```

```bash
kubectl apply -f service.yaml
```

**4. Verify Deployment**:
```bash
# Check deployment
kubectl get deployment -n mock-service

# Check pods
kubectl get pods -n mock-service

# Check service
kubectl get svc -n mock-service

# Get LoadBalancer IP (if using MetalLB or cloud provider)
kubectl get svc -n mock-service -o wide

# Check logs
kubectl logs -n mock-service deployment/mock-email-service

# Describe pod
kubectl describe pod -n mock-service <pod-name>
```

### Scale Application

```bash
# Scale deployment
kubectl scale deployment mock-email-service -n mock-service --replicas=3

# Autoscale
kubectl autoscale deployment mock-email-service -n mock-service \
  --cpu-percent=80 --min=2 --max=10

# Check HPA
kubectl get hpa -n mock-service
```

### Rolling Update

```bash
# Update image
kubectl set image deployment/mock-email-service \
  mock-email-service=<account-id>.dkr.ecr.us-east-1.amazonaws.com/mock-email-service:v2 \
  -n mock-service

# Check rollout status
kubectl rollout status deployment/mock-email-service -n mock-service

# View rollout history
kubectl rollout history deployment/mock-email-service -n mock-service

# Rollback
kubectl rollout undo deployment/mock-email-service -n mock-service
```

## Monitoring and Troubleshooting

### View Cluster Resources

```bash
# All namespaces
kubectl get all -A

# Specific namespace
kubectl get all -n mock-service

# Resource usage
kubectl top nodes
kubectl top pods -A
```

### Debug Pods

```bash
# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# View logs
kubectl logs <pod-name> -n <namespace>

# Follow logs
kubectl logs -f <pod-name> -n <namespace>

# Previous pod logs
kubectl logs <pod-name> -n <namespace> --previous

# Exec into pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
```

### Debug Nodes

```bash
# Describe node
kubectl describe node <node-name>

# SSH to node
ssh -J ec2-user@<bastion-ip> ubuntu@<node-ip>

# Check kubelet logs
sudo journalctl -u kubelet -f

# Check kubelet status
sudo systemctl status kubelet

# Check containerd
sudo crictl ps
sudo crictl images
sudo crictl logs <container-id>
```

### Debug Services

```bash
# Describe service
kubectl describe svc <service-name> -n <namespace>

# Check endpoints
kubectl get endpoints <service-name> -n <namespace>

# Test service from within cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod:
wget -O- http://mock-email-service.mock-service.svc.cluster.local
```

### Debug Network

```bash
# Check Calico status
kubectl get pods -n kube-system | grep calico

# Check pod network
kubectl exec -it <pod-name> -n <namespace> -- ip addr

# Check service CIDR
kubectl cluster-info dump | grep -i service-cluster-ip-range

# Check DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

### Common Issues

**Issue**: Nodes NotReady

```bash
# Check kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 50

# Check CNI
kubectl get pods -n kube-system | grep calico

# Restart kubelet
sudo systemctl restart kubelet
```

**Issue**: Pods stuck in Pending

```bash
# Describe pod to see reason
kubectl describe pod <pod-name> -n <namespace>

# Common reasons:
# - Insufficient resources
# - Node selector/affinity not matching
# - PVC not bound
```

**Issue**: Pods stuck in ContainerCreating

```bash
# Check CNI
kubectl get pods -n kube-system

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

## Networking

### Calico Configuration

**View Calico configuration**:
```bash
# Get IP pools
kubectl get ippools

# Get Calico nodes
kubectl get nodes -o wide
```

**Network Policy Example**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-same-namespace
  namespace: mock-service
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
```

### Service Types

**ClusterIP** (default):
```yaml
spec:
  type: ClusterIP
```

**NodePort**:
```yaml
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
```

**LoadBalancer** (requires cloud provider or MetalLB):
```yaml
spec:
  type: LoadBalancer
```

## Storage

### EmptyDir (temporary storage)

```yaml
volumes:
- name: cache
  emptyDir: {}
```

### HostPath (node storage)

```yaml
volumes:
- name: data
  hostPath:
    path: /mnt/data
    type: DirectoryOrCreate
```

### AWS EBS Volumes

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ebs-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  awsElasticBlockStore:
    volumeID: vol-xxxxx
    fsType: ext4
```

## Security

### RBAC

**Create ServiceAccount**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: mock-service
```

**Create Role**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: mock-service
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

**Create RoleBinding**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: mock-service
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: mock-service
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### Secrets

```bash
# Create secret
kubectl create secret generic db-password \
  --from-literal=password=mysecretpassword \
  -n mock-service

# Use secret in pod
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-password
      key: password
```

## Upgrading

### Upgrade Control Plane

```bash
# Check current version
kubectl version

# Update kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.30.0-00
sudo apt-mark hold kubeadm

# Plan upgrade
sudo kubeadm upgrade plan

# Perform upgrade
sudo kubeadm upgrade apply v1.30.0

# Drain node
kubectl drain <control-plane-node> --ignore-daemonsets

# Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet=1.30.0-00 kubectl=1.30.0-00
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Uncordon node
kubectl uncordon <control-plane-node>
```

### Upgrade Worker Nodes

```bash
# For each worker node:

# Update kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm=1.30.0-00
sudo apt-mark hold kubeadm

# Drain node (from control plane)
kubectl drain <worker-node> --ignore-daemonsets --delete-emptydir-data

# Upgrade node config
sudo kubeadm upgrade node

# Upgrade kubelet
sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet=1.30.0-00 kubectl=1.30.0-00
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Uncordon node (from control plane)
kubectl uncordon <worker-node>
```

---

## Summary

This Kubernetes setup provides:
- **Self-hosted cluster** on AWS with kubeadm
- **Containerd runtime** for container management
- **Calico CNI** for pod networking
- **Secure architecture** with bastion host access
- **Production-ready configuration** with 3 nodes
- **Application deployment** examples
- **Monitoring and troubleshooting** tools

For architecture details, see [ARCHITECTURE.md](../ARCHITECTURE.md).
For deployment steps, see [DEPLOYMENT.md](../DEPLOYMENT.md).
