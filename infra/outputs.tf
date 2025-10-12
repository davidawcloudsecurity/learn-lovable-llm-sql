output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.text_to_sql_vpc.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.text_to_sql_vpc.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private_subnets[*].id
}

output "nat_gateway_ip" {
  description = "Public IP of NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.text_to_sql_db.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.text_to_sql_db.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.text_to_sql_db.db_name
}

output "rds_secret_arn" {
  description = "ARN of the RDS credentials secret"
  value       = aws_secretsmanager_secret.rds_credentials.arn
  sensitive   = true
}

output "rds_connection_string" {
  description = "RDS connection string (without password)"
  value       = "postgresql://${var.rds_username}@${aws_db_instance.text_to_sql_db.address}:${aws_db_instance.text_to_sql_db.port}/${var.rds_database_name}"
  sensitive   = true
}
