variable "aws_region" {
  description = "AWS region for Amplify deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "text-to-sql"
}

variable "custom_domain" {
  description = "Custom domain name (optional)"
  type        = string
  default     = ""
}