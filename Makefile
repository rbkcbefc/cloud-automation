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
