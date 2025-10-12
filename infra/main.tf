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
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "text-to-sql-chatbot"
}

variable "dataset_s3_bucket" {
  description = "S3 bucket containing the housing dataset"
  type        = string
}

variable "db_master_username" {
  description = "Master username for RDS PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "housingdb"
}

# Random password for RDS
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Store DB password in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-db-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.postgresql.address
    port     = 5432
    dbname   = var.db_name
  })
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id, aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}

# Security Group for MemoryDB
resource "aws_security_group" "memorydb" {
  name        = "${var.project_name}-memorydb-sg"
  description = "Security group for MemoryDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-memorydb-sg"
  }
}

# Security Group for Bastion Host
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for Bastion host"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgresql" {
  identifier              = "${var.project_name}-postgres"
  engine                  = "postgres"
  engine_version          = "15.4"
  instance_class          = "db.t3.medium"
  allocated_storage       = 100
  storage_type            = "gp3"
  db_name                 = var.db_name
  username                = var.db_master_username
  password                = random_password.db_password.result
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 7
  multi_az                = false

  tags = {
    Name = "${var.project_name}-postgresql"
  }
}

# MemoryDB Subnet Group
resource "aws_memorydb_subnet_group" "main" {
  name       = "${var.project_name}-memorydb-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-memorydb-subnet-group"
  }
}

# MemoryDB ACL
resource "aws_memorydb_acl" "main" {
  name = "${var.project_name}-memorydb-acl"

  user_names = [aws_memorydb_user.main.id]

  tags = {
    Name = "${var.project_name}-memorydb-acl"
  }
}

# MemoryDB User
resource "aws_memorydb_user" "main" {
  user_name     = "admin"
  access_string = "on ~* &* +@all"

  authentication_mode {
    type      = "password"
    passwords = [random_password.db_password.result]
  }

  tags = {
    Name = "${var.project_name}-memorydb-user"
  }
}

# MemoryDB Cluster
resource "aws_memorydb_cluster" "main" {
  name                   = "${var.project_name}-memorydb"
  node_type              = "db.t4g.small"
  num_shards             = 1
  num_replicas_per_shard = 1
  acl_name               = aws_memorydb_acl.main.name
  engine_version         = "7.0"
  subnet_group_name      = aws_memorydb_subnet_group.main.name
  security_group_ids     = [aws_security_group.memorydb.id]
  snapshot_retention_limit = 5

  tags = {
    Name = "${var.project_name}-memorydb"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambda Policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.dataset_s3_bucket}",
          "arn:aws:s3:::${var.dataset_s3_bucket}/*"
        ]
      }
    ]
  })
}

# Lambda Layer for dependencies (placeholder - needs actual layer creation)
resource "aws_lambda_layer_version" "dependencies" {
  filename            = "lambda_layer.zip" # You'll need to create this
  layer_name          = "${var.project_name}-dependencies"
  compatible_runtimes = ["python3.12"]
  description         = "Dependencies for text-to-sql functions"
}

# Data Indexer Lambda Function
resource "aws_lambda_function" "data_indexer" {
  filename         = "data_indexer.zip" # You'll need to create this
  function_name    = "${var.project_name}-DataIndexerFunction"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 512
  source_code_hash = filebase64sha256("data_indexer.zip")

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SECRET_NAME     = aws_secretsmanager_secret.db_credentials.name
      DB_HOST         = aws_db_instance.postgresql.address
      DB_NAME         = var.db_name
      MEMORYDB_ENDPOINT = aws_memorydb_cluster.main.cluster_endpoint[0].address
    }
  }

  layers = [aws_lambda_layer_version.dependencies.arn]

  tags = {
    Name = "${var.project_name}-data-indexer"
  }
}

# Text to SQL Lambda Function
resource "aws_lambda_function" "text_to_sql" {
  filename         = "text_to_sql.zip" # You'll need to create this
  function_name    = "${var.project_name}-TextToSQLFunction"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 1024
  source_code_hash = filebase64sha256("text_to_sql.zip")

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SECRET_NAME       = aws_secretsmanager_secret.db_credentials.name
      DB_HOST           = aws_db_instance.postgresql.address
      DB_NAME           = var.db_name
      MEMORYDB_ENDPOINT = aws_memorydb_cluster.main.cluster_endpoint[0].address
      AWS_REGION        = var.aws_region
    }
  }

  layers = [aws_lambda_layer_version.dependencies.arn]

  tags = {
    Name = "${var.project_name}-text-to-sql"
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type", "x-api-key"]
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.text_to_sql.invoke_arn
  integration_method = "POST"
}

# API Gateway Route
resource "aws_apigatewayv2_route" "query" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /query"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "prod"
  auto_deploy = true

  tags = {
    Name = "${var.project_name}-api-stage"
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.text_to_sql.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# API Key
resource "aws_apigatewayv2_authorizer" "api_key" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "REQUEST"
  name             = "${var.project_name}-api-key-auth"
  identity_sources = ["$request.header.x-api-key"]
}

# Bastion Host IAM Role
resource "aws_iam_role" "bastion_role" {
  name = "${var.project_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "bastion_s3" {
  name = "${var.project_name}-bastion-s3-policy"
  role = aws_iam_role.bastion_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${var.dataset_s3_bucket}",
        "arn:aws:s3:::${var.dataset_s3_bucket}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-bastion-profile"
  role = aws_iam_role.bastion_role.name
}

# Bastion Host
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y postgresql15
    EOF
  )

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgresql.endpoint
}

output "memorydb_endpoint" {
  description = "MemoryDB cluster endpoint"
  value       = aws_memorydb_cluster.main.cluster_endpoint[0].address
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = "${aws_apigatewayv2_stage.prod.invoke_url}/query"
}

output "bastion_instance_id" {
  description = "Bastion host instance ID"
  value       = aws_instance.bastion.id
}

output "db_secret_name" {
  description = "Database credentials secret name"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "data_indexer_function_name" {
  description = "Data Indexer Lambda function name"
  value       = aws_lambda_function.data_indexer.function_name
}

output "text_to_sql_function_name" {
  description = "Text to SQL Lambda function name"
  value       = aws_lambda_function.text_to_sql.function_name
}
