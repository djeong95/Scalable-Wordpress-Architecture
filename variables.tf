variable "vpc_cidr_block" {
  type = string
  description = "VPC CIDR Block"
}

variable "public_subnet_cidrs" {
    type = list(string)
    description = "Public Subnet CIDR values"
}

variable "private_subnet_cidrs_db" {
    type = list(string)
    description = "Private DB Subnet CIDR values"
}

variable "private_subnet_cidrs_efs" {
    type = list(string)
    description = "Private EFS Subnet CIDR values"
}

variable "azs" {
    type = list(string)
    description = "Availability Zones"
}

variable "region" {
  type = string
  description = "AWS region where AWS resources will be created"
  sensitive = true
}

variable "my_access_key" {
  type = string
  description = "AWS credentials access key - very sensitive"
  sensitive = true
}

variable "my_secret_key" {
  type = string
  description = "AWS credentials secret key - very sensitive"
  sensitive = true
}

variable "DBPassword" {
  type = string
  description = "Wordpress DB Password"
  sensitive = true
}

variable "DBRootPassword" {
  type = string
  description = "Wordpress DBRoot Password"
  sensitive = true
}

variable "DBUser" {
  type = string
  description = "Wordpress Database User"
}

variable "DBName" {
  type = string
  description = "Wordpress Database Name"
  sensitive = true
}

variable "image_id" {
  type = string
  description = "The id of the machine image (AMI) to use for the server."

  validation {
    condition = length(var.image_id) > 4 && substr(var.image_id, 0, 4) == "ami-"
    error_message = "The image_id value must be a valid AMI id, starting with \"ami-\"."
  }
}

variable "db_identifier" {
  type = string
  description = "DB Identifier"
}

variable "db_storage_type" {
  type = string
  description = "DB Storage Type like gp2 or gp3"
}

variable "db_engine" {
  type = string
  description = "DB Engine"
}

variable "db_engine_version" {
  type = string
  description = "DB Engine Version"
}

variable "db_instance_class" {
  type = string
  description = "DB Instance Class"
}

variable "ec2_instance_type" {
  type = string
  description = "EC2 Instance Type"
}

