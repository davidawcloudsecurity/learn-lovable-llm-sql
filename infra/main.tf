terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
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

# Generate random password for RDS
resource "random_password" "rds_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "rds_credentials" {
  name = "text-to-sql-rds-credentials"
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.rds_username
    password = random_password.rds_password.result
    engine   = "postgres"
    host     = aws_db_instance.text_to_sql_db.address
    port     = aws_db_instance.text_to_sql_db.port
    dbname   = var.rds_database_name
  })
}

# Create RDS instance
resource "aws_db_instance" "text_to_sql_db" {
  identifier              = "text-to-sql-db"
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  engine                  = "postgres"
  engine_version          = var.postgres_version
  username                = var.rds_username
  password                = random_password.rds_password.result
  db_name                 = var.rds_database_name
  publicly_accessible     = true
  skip_final_snapshot     = true
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  
  # Security groups will be created separately
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  
  # Enable performance insights
  performance_insights_enabled = true
  
  # Enable storage encryption
  storage_encrypted = true
  
  # Enable Enhanced Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  
  tags = {
    Name        = "text-to-sql-database"
    Project     = "text-to-sql-chatbot"
    Environment = var.environment
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "text-to-sql-rds-sg"
  description = "Security group for Text-to-SQL RDS instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from anywhere (for demo)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "text-to-sql-rds-sg"
    Project = "text-to-sql-chatbot"
  }
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Database initialization script
resource "aws_db_parameter_group" "text_to_sql_pg" {
  name   = "text-to-sql-parameter-group"
  family = "postgres15"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
}

