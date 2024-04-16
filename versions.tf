# https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/versions.tf
terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 5.30"
    }
  }
}
