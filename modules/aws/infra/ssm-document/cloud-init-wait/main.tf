locals {
  raw_config = yamldecode(file(var.config_file))
  config = {
    environment = lookup(local.raw_config.environments, var.environment, "Error: Invalid Environment!")
  }
  common_tags = {
    Environment = var.environment
    Managed-By  = "tf"  
  }
}

variable "environment" {}
variable "config_file" {}

provider "aws" {
  region = local.config.environment.region
}

variable "cloud_init_wait_name_doc_name" {
  default = "cloud-init-wait"
}

resource "aws_ssm_document" "cloud-init-wait" {
  name = var.cloud_init_wait_name_doc_name
  document_type = "Command"
  document_format = "YAML"
  content = <<-DOC
    schemaVersion: '2.2'
    description: Wait for cloud init to finish
    mainSteps:
    - action: aws:runShellScript
      name: StopOnLinux
      precondition:
        StringEquals:
        - platformType
        - Linux
      inputs:
        runCommand:
          - cloud-init status --wait
    DOC

    tags = merge(
      {
        Name = var.cloud_init_wait_name_doc_name
      },
      local.common_tags
    )
}