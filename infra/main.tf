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

# Create VPC
resource "aws_vpc" "text_to_sql_vpc" {
  cidr_block           = "172.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "text-to-sql-vpc"
    Project     = "text-to-sql-chatbot"
    Environment = var.environment
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "text_to_sql_igw" {
  vpc_id = aws_vpc.text_to_sql_vpc.id

  tags = {
    Name    = "text-to-sql-igw"
    Project = "text-to-sql-chatbot"
  }
}

# Create Public Subnets
resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.text_to_sql_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "text-to-sql-public-${count.index + 1}"
    Project = "text-to-sql-chatbot"
    Type    = "Public"
  }
}

# Create Private Subnets
resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.text_to_sql_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name    = "text-to-sql-private-${count.index + 1}"
    Project = "text-to-sql-chatbot"
    Type    = "Private"
  }
}

# Create Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.text_to_sql_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.text_to_sql_igw.id
  }

  tags = {
    Name    = "text-to-sql-public-rt"
    Project = "text-to-sql-chatbot"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public_assoc" {
  count = length(aws_subnet.public_subnets)

  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Create NAT Gateway in Public Subnet
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name    = "text-to-sql-nat-eip"
    Project = "text-to-sql-chatbot"
  }
}

resource "aws_nat_gateway" "text_to_sql_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name    = "text-to-sql-nat"
    Project = "text-to-sql-chatbot"
  }

  depends_on = [aws_internet_gateway.text_to_sql_igw]
}

# Create Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.text_to_sql_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.text_to_sql_nat.id
  }

  tags = {
    Name    = "text-to-sql-private-rt"
    Project = "text-to-sql-chatbot"
  }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private_assoc" {
  count = length(aws_subnet.private_subnets)

  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
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

# Update RDS instance resource
resource "aws_db_instance" "text_to_sql_db" {
  identifier              = "text-to-sql-db"
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  engine                  = "postgres"
  engine_version          = var.postgres_version
  username                = var.rds_username
  password                = random_password.rds_password.result
  db_name                 = var.rds_database_name
  publicly_accessible     = true  # Set to false for production
  skip_final_snapshot     = true
  backup_retention_period = 7
  
  # Updated network configuration
  db_subnet_group_name    = aws_db_subnet_group.text_to_sql_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  
  # Enable performance insights
  performance_insights_enabled = true
  
  # Enable storage encryption
  storage_encrypted = true
  
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
  vpc_id      = aws_vpc.text_to_sql_vpc.id  # Updated to use new VPC

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.text_to_sql_vpc.cidr_block]  # Allow from entire VPC
  }
/* Reserved for bastion host
  ingress {
    description = "PostgreSQL from specific IP (for external access)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP_ADDRESS/32"]  # Replace with your actual IP
  }
*/
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

# Update RDS instance to use private subnets
resource "aws_db_subnet_group" "text_to_sql_db_subnet_group" {
  name       = "text-to-sql-db-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id  # Use private subnets for RDS

  tags = {
    Name    = "text-to-sql-db-subnet-group"
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

