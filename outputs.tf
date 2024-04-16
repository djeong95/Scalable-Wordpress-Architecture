# output "vpcs" {
#   description = "VPC Outputs"
#   value       = { for vpc in aws_vpc.this : vpc.tags.Name => { "cidr_block" : vpc.cidr_block, "id" : vpc.id } }
# }

output "db_username" {
    value = nonsensitive(aws_db_instance.this.username)
    description = "The username used for the database instance."
}

output "db_endpoint" {
    value = nonsensitive(aws_db_instance.this.endpoint)
    description = "The username used for the database instance."
}