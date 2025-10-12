variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "text-to-sql-chatbot"
}

variable "dataset_s3_bucket" {
  description = "S3 bucket containing the housing dataset"
  type        = string
  default     = "your-s3-bucket-name"  # Will be overridden by terraform.tfvars
}

variable "db_master_username" {
  description = "Master username for RDS PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Master username for RDS PostgreSQL"
  type        = string
  default     = "P@ssw0rd123456789" # to be replace
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "housingdb"
}
