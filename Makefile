usage:
	@echo "Usage 1: make build_base_amis"
	@echo "Usage 2: build_docker_amis Note: Build Docker AMIs on top of Base AMIs. Run from Project root directory with var-file containing Base AMI IDs."
	@echo "Usage 3: make create_role name=<<Your_New_Ansible_Role_Name>> Eg. make create_role name=docker"
	@echo "Usage 4: make runpb name=<<Your_Ansible_Playbook>> Eg. make runpb name=setup_docker"
	@echo "Usage 5: make create_tf_module name=<<Your_New_TF_Module_NAME>> provider=aws"
  
build_base_amis:
	@echo "Building Base AMIs"
	packer build ami/setup-aws-base-image.pkr.hcl

build_docker_amis:
	@echo "Building Docker AMIs on top of Base AMIs"
	packer build -var-file=ami/variables.auto.pkrvars.hcl  ami/setup-aws-docker-image.pkr.hcl

build_containerd_amis:
	@echo "Building Containerd AMIs on top of Base AMIs"
	packer build -var-file=ami/variables.auto.pkrvars.hcl  ami/setup-aws-containerd-image.pkr.hcl

build_aws_ecr_ecs_amis:
	@echo "Building AWS ECS AMIs w/ ECR Helper on top of Docker AMIs"
	packer build -var-file=ami/variables.auto.pkrvars.hcl  ami/setup-aws-ecr-ecs-image.pkr.hcl

create_role:
	@echo "Creating role: ${name}"
	mkdir -p roles/${name}/{defaults,files,handlers,meta,tasks,templates,vars}
	touch roles/${name}/defaults/main.yml
	@echo "---" > roles/${name}/defaults/main.yml
	touch roles/${name}/handlers/main.yml
	@echo "---" > roles/${name}/handlers/main.yml
	touch roles/${name}/meta/main.yml
	@echo "---\ndependencies: []" > roles/${name}/meta/main.yml
	touch roles/${name}/tasks/main.yml
	@echo "---" > roles/${name}/tasks/main.yml
	touch roles/${name}/vars/main.yml
	@echo "---" > roles/${name}/vars/main.yml

runpb:
	@echo "Running Playbook: ${name}.yml"
	ansible-playbook playbooks/${name}.yml

create_tf_module:
	@echo "Creating Terraform Module: ${name} and Cloud Provider: ${provider}"
	mkdir -p modules/${provider}/infra/${name}
	touch modules/${provider}/infra/${name}/main.tf
	touch modules/${provider}/infra/${name}/outputs.tf

setup_k8s_kubeadm_sh_cp_node:
	ansible-playbook -vv -i "<<IP>>," -u ubuntu playbooks/setup-k8s-kubeadm-sh.yml --extra-vars "ansible_user=ubuntu \
	k8s_node_role=controlplane control_plane_host=<<IP>> current_node_name=k8s-kubeadm-sh-cp-node" --ssh-common-args  \
	'-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/rbkbusde-us-east-1.pem'

setup_k8s_kubeadm_sh_dp_node:
	ansible-playbook -vv -i hosts.aws_ec2.yml -e 'targets=tag_Name_k8s_kubeadm_sh_dp_node_1' \
	-u ubuntu playbooks/setup-k8s-kubeadm-sh.yml --extra-vars "ansible_user=ubuntu k8s_node_role=dataplane \
	control_plane_host=<<IP>>" \
	--ssh-common-args  '-o \"ProxyCommand ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	-i ~/.ssh/rbkbusde-us-east-1.pem -W %h:%p\"'

init_k8s_kubeadm_dh_cp_node:
	sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-bind-port=6443 --control-plane-endpoint=<<IP>>:6443

k8s_kubeadm_sh_dp_pull_image:
	ECR_PASSWORD=$(aws ecr get-login-password --region us-east-1)
	sudo crictl pull --creds "AWS:$ECR_PASSWORD" ${image_uri}

install_tf_apple_silicon_helper:
	brew install kreuzwerker/taps/m1-terraform-provider-helper
