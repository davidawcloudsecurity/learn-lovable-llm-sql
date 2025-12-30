variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for RDS setup"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name for EC2 instance (optional)"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID where RDS will be deployed"
  type        = string
  default     = ""  # Set your VPC ID or use data source to get default VPC
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "rds_username" {
  description = "Master username for RDS"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "rds_database_name" {
  description = "Initial database name"
  type        = string
  default     = "company"
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "17.4"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["172.168.1.0/24", "172.168.2.0/24", "172.168.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["172.168.10.0/24", "172.168.11.0/24", "172.168.12.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ""
//  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
