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

# Database initialization using local-exec provisioner
resource "null_resource" "database_setup" {
  depends_on = [aws_db_instance.text_to_sql_db]

  triggers = {
    rds_endpoint = aws_db_instance.text_to_sql_db.address
  }

  provisioner "local-exec" {
    command = <<EOF
      # Wait for RDS to be ready
      until pg_isready -h ${aws_db_instance.text_to_sql_db.address} -p ${aws_db_instance.text_to_sql_db.port} -U ${var.rds_username}; do
        echo "Waiting for database to be ready..."
        sleep 10
      done

      # Connect and initialize database
      PGPASSWORD=${random_password.rds_password.result} psql \
        -h ${aws_db_instance.text_to_sql_db.address} \
        -p ${aws_db_instance.text_to_sql_db.port} \
        -U ${var.rds_username} \
        -d ${var.rds_database_name} \
        -c "
          CREATE TABLE IF NOT EXISTS employees (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            department VARCHAR(50),
            salary DECIMAL(10,2),
            hire_date DATE
          );

          CREATE TABLE IF NOT EXISTS departments (
            id SERIAL PRIMARY KEY,
            name VARCHAR(50),
            budget DECIMAL(12,2)
          );

          INSERT INTO departments (name, budget) VALUES 
          ('Engineering', 1000000),
          ('Sales', 500000),
          ('Marketing', 300000)
          ON CONFLICT DO NOTHING;

          INSERT INTO employees (name, department, salary, hire_date) VALUES
          ('John Doe', 'Engineering', 75000, '2022-01-15'),
          ('Jane Smith', 'Sales', 65000, '2021-03-20'),
          ('Bob Johnson', 'Engineering', 80000, '2020-11-10'),
          ('Alice Brown', 'Marketing', 60000, '2023-02-01')
          ON CONFLICT DO NOTHING;
        "
    EOF

    interpreter = ["/bin/bash", "-c"]
  }
}

