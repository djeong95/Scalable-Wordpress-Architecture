# This script was inspired by Adrian Cantrill's github. 
# Instead of using the console, this uses terraform to build everything in AWS
# https://github.com/acantril/learn-cantrill-io-labs/tree/master/aws-elastic-wordpress-evolution

# ==============================================================================
# Provider Configuration
# ==============================================================================
# Configures the AWS provider with credentials and sets the region.
provider "aws" {
  region = var.region 
  access_key = var.my_access_key
  secret_key = var.my_secret_key
}

# ==============================================================================
# Network Configuration
# ==============================================================================
# Create a VPC for the scalable WordPress Project
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "Scalable_WordPress_Project"
  }
}

# Creates public subnets for the VPC.
resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.this.id
  cidr_block = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

# Creates private subnets for database in the VPC.
resource "aws_subnet" "private_subnets_db" {
  count = length(var.private_subnet_cidrs_db)
  vpc_id = aws_vpc.this.id
  cidr_block = element(var.private_subnet_cidrs_db, count.index)
  availability_zone = element(var.azs, count.index) 

  tags = {
    Name = "Private DB Subnet ${count.index + 1}"
  }
}

# Creates private subnets for EFS in the VPC.
resource "aws_subnet" "private_subnets_efs" {
  count = length(var.private_subnet_cidrs_efs)
  vpc_id = aws_vpc.this.id
  cidr_block = element(var.private_subnet_cidrs_efs, count.index)
  availability_zone = element(var.azs, count.index) 

  tags = {
    Name = "Private EFS Subnet ${count.index + 1}"
  }
}

# Creates an Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "Scalable_WordPress_Project_IGW"
  }
}

# Creates a route table for public subnets with a default route through the Internet Gateway.
resource "aws_route_table" "RT_Public" {
  vpc_id = aws_vpc.this.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Scalable_WordPress_Project_RT_Pub"
  }
}

# Associates public subnets with the public route table.
resource "aws_route_table_association" "public_subnet_assoc" {
  count = length(var.public_subnet_cidrs)
  subnet_id = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.RT_Public.id
}

# ==============================================================================
# Security Group Configuration
# ==============================================================================
# Defines security groups for various components including Wordpress, database, load balancer, and EFS.

# WordPress security group to control inbound and outbound traffic for associated resources.
resource "aws_security_group" "SGWordpress" {
  name = "SGWordpress"
  description = "Control access to Wordpress Instance(s)"
  vpc_id = aws_vpc.this.id

ingress {
  description = "Allow HTTP IPv4 IN"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

}

# DB security group to control inbound and outbound traffic for associated resources.
resource "aws_security_group" "SGDatabase" {
  name = "SGDatabase"
  description = "Control access to Database"
  vpc_id = aws_vpc.this.id

ingress {
  description = "Allow MySQL IN"
  from_port = 3306
  to_port = 3306
  protocol = "tcp"
  security_groups = [aws_security_group.SGWordpress.id]
}

egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

}

# ALB security group to control inbound and outbound traffic for associated resources.
resource "aws_security_group" "SGLoadBalancer" {
  name = "SGLoadBalancer"
  description = "Control access to Load Balancer"
  vpc_id = aws_vpc.this.id

ingress {
  description = "Allow HTTP IPv4 IN"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

}

# EFS security group to control inbound and outbound traffic for associated resources.
resource "aws_security_group" "SGEFS" {
  name = "SGEFS"
  description = "Control access to EFS"
  vpc_id = aws_vpc.this.id

ingress {
  description = "Allow NFS/EFS IPv4 IN"
  from_port = 2049
  to_port = 2049
  protocol = "tcp"
  security_groups = [aws_security_group.SGWordpress.id]
}

egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

}

# ==============================================================================
# IAM Configuration for WordPress
# ==============================================================================

# This IAM configuration allows EC2 instances to interact with other AWS services like EFS.
resource "aws_iam_role" "WordpressRole" {
  name = "WordpressRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonElasticFileSystemClientFullAccess", "arn:aws:iam::aws:policy/AmazonSSMFullAccess", "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
}

# Create IAM instance Profile from the role specified
resource "aws_iam_instance_profile" "WordPressInstanceProfile" {
  name = "WordPressInstanceProfile"
  role = aws_iam_role.WordpressRole.name
}

# ==============================================================================
# EFS File System, Backup Policies, and Mount Targets configurations
# ==============================================================================
resource "aws_efs_file_system" "EFS" {
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"
  encrypted = "false"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "A4L-WORDPRESS-CONTENT"
  }
}

resource "aws_efs_backup_policy" "EFSBackupPolicy" {
  file_system_id = aws_efs_file_system.EFS.id

  backup_policy {
    status = "ENABLED"
  }
}
resource "aws_efs_mount_target" "EFSMount" {
    count = length(var.private_subnet_cidrs_efs)
    file_system_id = aws_efs_file_system.EFS.id
    subnet_id = aws_subnet.private_subnets_efs[count.index].id
    security_groups = [aws_security_group.SGEFS.id]

}

# ==============================================================================
# RDS configurations
# ==============================================================================

resource "aws_db_subnet_group" "this" {
  # count = length(aws_subnet.private_subnets_db)
  
  name = "wordpressrdssubnetgroup" 
  description = "RDS Subnet Group for Wordpress"
  subnet_ids = [for subnet in aws_subnet.private_subnets_db : subnet.id]
  
}

resource "aws_db_instance" "this" {
  
  identifier = var.db_identifier
  username = aws_ssm_parameter.DBUser.value
  password = aws_ssm_parameter.DBPassword.value
  storage_type = var.db_storage_type
  engine = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  storage_encrypted = "true"
  db_name = aws_ssm_parameter.DBName.value

  allocated_storage = 20
  db_subnet_group_name = aws_db_subnet_group.this.id
  vpc_security_group_ids = [aws_security_group.SGDatabase.id]
  availability_zone = var.azs[0]
  
  # For `terraform destroy` to work: https://stackoverflow.com/questions/50930470/terraform-error-rds-cluster-finalsnapshotidentifier-is-required-when-a-final-s
  skip_final_snapshot = true
  backup_retention_period = 0
  apply_immediately = true
}

# ==============================================================================
# ALB / ASG Configurations
# ==============================================================================

resource "aws_lb" "this" {
  name = "A4LWORDPRESSALB" 
  internal = false
  load_balancer_type = "application"
  ip_address_type = "ipv4"
  security_groups = [aws_security_group.SGLoadBalancer.id]
  subnets = [for subnet in aws_subnet.public_subnets : subnet.id]

}

resource "aws_lb_target_group" "this" {
  name = "A4LWORDPRESSALBTG"
  port = 80
  protocol = "HTTP"
  protocol_version = "HTTP1"
  vpc_id = aws_vpc.this.id
  
  lifecycle {
    create_before_destroy = true
  }
  health_check {
    path = "/"
    healthy_threshold = 5
    unhealthy_threshold = 2
    interval = 30
  }
}

resource "aws_alb_listener" "this" {
  default_action {
    target_group_arn = aws_lb_target_group.this.arn
    type = "forward"
  }
  load_balancer_arn = aws_lb.this.arn
  port = 80
  protocol = "HTTP"
}

resource "aws_autoscaling_group" "this" {
  
  name = "A4LWORDPRESSASG"
  min_size = 1
  max_size = 3
  desired_capacity = 1
  health_check_type = "ELB"
  vpc_zone_identifier = [for subnet in aws_subnet.public_subnets : subnet.id]

  launch_template {
    id = aws_launch_template.this.id 
    version = aws_launch_template.this.latest_version
  }
  
  depends_on = [
    aws_lb.this, aws_db_instance.this
  ]

  target_group_arns = [
    aws_lb_target_group.this.arn
  ]
  
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "Wordpress-ASG"
    propagate_at_launch = true
  }

  enabled_metrics = [
    "GroupMaxSize",
    "GroupMinSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"
}

resource "aws_autoscaling_policy" "HighCPUScaleOut" {
  name = "HIGHCPU"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_cloudwatch_metric_alarm" "HighCPU" {
  alarm_name = "WordpressHIGHCPU"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods = 1
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = 300
  statistic = "Average"
  threshold = 40
  alarm_description = "This metric monitors high EC2 CPU utilization"
  alarm_actions     = [aws_autoscaling_policy.HighCPUScaleOut.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
}

resource "aws_autoscaling_policy" "LowCPUScaleIn" {
  name = "LOWCPU"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_cloudwatch_metric_alarm" "LowCPU" {
  alarm_name = "WordpressLOWCPU"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = 1
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = 300
  statistic = "Average"
  threshold = 40
  alarm_description = "This metric monitors low EC2 CPU utilization"
  alarm_actions = [aws_autoscaling_policy.LowCPUScaleIn.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
}

resource "aws_launch_template" "this" {
  description = "App only, uses EFS filesystem defined in /A4L/Wordpress/EFSFSID, ALB home added to WP Database"
  
  image_id = var.image_id
  instance_type = var.ec2_instance_type

  vpc_security_group_ids = [aws_security_group.SGWordpress.id]
  
  iam_instance_profile {
    arn = aws_iam_instance_profile.WordPressInstanceProfile.arn
  }
  
  credit_specification {
    cpu_credits = "unlimited"
  }

  # block_A4Lice_mappings {
  #   A4Lice_name = "/A4L/sda1"
  #   ebs {
  #     volume_size = 8
  #     volume_type = "gp3"
  #   }
  # }
  
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
    http_put_response_hop_limit = 2
  }

  user_data = filebase64("${path.module}/user_data.sh")
}
# ==============================================================================
# SSM Parameters for WordPress/DB/EFS/ALB
# ==============================================================================

resource "aws_ssm_parameter" "DBEndpoint" {
  name = "/A4L/Wordpress/DBEndpoint" 
  description = "Wordpress Endpoint Name"
  type = "String"
  data_type = "text"
  value = aws_db_instance.this.endpoint 
  
}

resource "aws_ssm_parameter" "DBName" {
  name = "/A4L/Wordpress/DBName" 
  description = "Wordpress Database Name"
  type = "String"
  data_type = "text"
  value = var.DBName
}

resource "aws_ssm_parameter" "DBUser" {
  name = "/A4L/Wordpress/DBUser" 
  description = "Wordpress Database User"
  type = "String"
  data_type = "text"
  value = var.DBUser
}

resource "aws_ssm_parameter" "EFSFSID" {
  name = "/A4L/Wordpress/EFSFSID" 
  description = "File System ID for Wordpress Content (wp-content)"
  type = "String"
  data_type = "text"
  value = aws_efs_file_system.EFS.id 
}

resource "aws_ssm_parameter" "ALBDNSNAME" {
  name = "/A4L/Wordpress/ALBDNSNAME" 
  description = "DNS Name of the Application Load Balancer for wordpress"
  type = "String"
  data_type = "text"
  value = aws_lb.this.dns_name
}

resource "aws_ssm_parameter" "DBPassword" {
  name = "/A4L/Wordpress/DBPassword" 
  description = "Wordpress DB Password"
  type = "SecureString"
  data_type = "text"
  value = var.DBPassword
  key_id = "alias/aws/ssm"
}

resource "aws_ssm_parameter" "DBRootPassword" {
  name = "/A4L/Wordpress/DBRootPassword" 
  description = "Wordpress DBRoot Password"
  type = "SecureString"
  data_type = "text"
  value = var.DBRootPassword
  key_id = "alias/aws/ssm"
}

