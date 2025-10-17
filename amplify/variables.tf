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

variable "github_repository" {
  description = "GitHub repository URL (https://github.com/username/repo)"
  type        = string
}

variable "custom_domain" {
  description = "Custom domain name (optional)"
  type        = string
  default     = ""
}