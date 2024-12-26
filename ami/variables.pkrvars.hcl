# Step 1: My Base AMI built on top of AWS lastest Ubuntu & CentOS AMIs
# AWS Provided latest Ubuntu AMI
source_ubuntu_ami = ""
# AWS Provided latest CentOS AMI
source_centos_ami = ""
# AWS Provided latest AL2023 AMI
source_al2023_ami = ""

# Step 2: Build Docker AMI based on My Base AMI 
my_ubuntu_base_ami = ""
my_centos_base_ami = ""
my_al2023_base_ami = ""

# Step 3: Build ECS AMI w/ ECR Helper on top of My Docker AMIs
my_ubuntu_docker_ami = ""
my_centos_docker_ami = ""
my_al2023_docker_ami = ""