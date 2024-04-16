# output "vpcs" {
#   description = "VPC Outputs"
#   value       = { for vpc in aws_vpc.this : vpc.tags.Name => { "cidr_block" : vpc.cidr_block, "id" : vpc.id } }
# }

output "alb_endpoint" {
    value = nonsensitive(aws_lb.this.dns_name)
    description = "The endpoint for the application load balancer."
}

output "db_endpoint" {
    value = nonsensitive(aws_db_instance.this.endpoint)
    description = "The endpoint for the database instance."
}