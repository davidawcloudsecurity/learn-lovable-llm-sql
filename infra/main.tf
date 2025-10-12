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
  default     = "P@ssw0rd123456789!" # to be replace
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
    password = var.db_password
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
  engine_version          = "17.4"
  instance_class          = "db.t3.medium"
  allocated_storage       = 100
  storage_type            = "gp3"
  db_name                 = var.db_name
  username                = var.db_master_username
  password                = var.db_password
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
    passwords = [var.db_password]
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

# Null resource to create required Python files
resource "null_resource" "create_python_files" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Create data_indexer.py if it doesn't exist
      if [ ! -f data_indexer.py ]; then
        echo "Creating data_indexer.py..."
        cat > data_indexer.py << 'PYFILE'
import json
import os
import boto3
import psycopg2
from psycopg2.extras import execute_values

bedrock_runtime = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-west-2'))
secretsmanager = boto3.client('secretsmanager', region_name=os.environ.get('AWS_REGION', 'us-west-2'))

def get_db_connection():
    secret_name = os.environ['SECRET_NAME']
    response = secretsmanager.get_secret_value(SecretId=secret_name)
    secret = json.loads(response['SecretString'])
    conn = psycopg2.connect(
        host=secret['host'],
        database=secret['dbname'],
        user=secret['username'],
        password=secret['password'],
        port=secret.get('port', 5432)
    )
    return conn

def create_embeddings_table(cursor):
    cursor.execute("CREATE EXTENSION IF NOT EXISTS vector;")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS table_embeddings (
            id SERIAL PRIMARY KEY,
            table_name VARCHAR(255),
            table_description TEXT,
            embedding vector(1536),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_table_embeddings_vector 
        ON table_embeddings USING ivfflat (embedding vector_cosine_ops)
        WITH (lists = 100);
    """)

def get_table_metadata(cursor):
    cursor.execute("""
        SELECT 
            t.table_name,
            array_agg(
                c.column_name || ' (' || c.data_type || 
                CASE WHEN c.is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END || ')'
                ORDER BY c.ordinal_position
            ) as columns
        FROM information_schema.tables t
        JOIN information_schema.columns c 
            ON t.table_name = c.table_name 
            AND t.table_schema = c.table_schema
        WHERE t.table_schema = 'public'
            AND t.table_type = 'BASE TABLE'
            AND t.table_name != 'table_embeddings'
        GROUP BY t.table_name;
    """)
    return cursor.fetchall()

def generate_table_description(table_name, columns):
    column_list = ', '.join(columns)
    description = f"Table: {table_name}. Columns: {column_list}"
    return description

def get_embedding(text):
    body = json.dumps({"inputText": text})
    response = bedrock_runtime.invoke_model(
        modelId='amazon.titan-embed-text-v1',
        body=body,
        contentType='application/json',
        accept='application/json'
    )
    response_body = json.loads(response['body'].read())
    return response_body['embedding']

def store_embeddings(cursor, table_name, description, embedding):
    cursor.execute("DELETE FROM table_embeddings WHERE table_name = %s;", (table_name,))
    cursor.execute("""
        INSERT INTO table_embeddings (table_name, table_description, embedding)
        VALUES (%s, %s, %s);
    """, (table_name, description, embedding))

def handler(event, context):
    print("Starting data indexer function")
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        print("Creating embeddings table if needed")
        create_embeddings_table(cursor)
        conn.commit()
        print("Retrieving table metadata")
        tables_metadata = get_table_metadata(cursor)
        print(f"Found {len(tables_metadata)} tables to process")
        embeddings_created = 0
        for table_name, columns in tables_metadata:
            print(f"Processing table: {table_name}")
            description = generate_table_description(table_name, columns)
            print(f"Description: {description}")
            embedding = get_embedding(description)
            print(f"Generated embedding with dimension: {len(embedding)}")
            store_embeddings(cursor, table_name, description, embedding)
            embeddings_created += 1
            print(f"Stored embedding for table: {table_name}")
        conn.commit()
        print(f"Successfully created {embeddings_created} embeddings")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully indexed {embeddings_created} tables',
                'tables_processed': embeddings_created
            })
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        if conn:
            conn.rollback()
        raise e
    finally:
        if conn:
            cursor.close()
            conn.close()
PYFILE
      fi

      # Create text_to_sql.py if it doesn't exist
      if [ ! -f text_to_sql.py ]; then
        echo "Creating text_to_sql.py..."
        cat > text_to_sql.py << 'PYFILE'
import json
import os
import boto3
import psycopg2
import redis
import hashlib
from psycopg2.extras import RealDictCursor

bedrock_runtime = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-west-2'))
secretsmanager = boto3.client('secretsmanager', region_name=os.environ.get('AWS_REGION', 'us-west-2'))
redis_client = None

def get_redis_client():
    global redis_client
    if redis_client is None:
        redis_client = redis.Redis(
            host=os.environ['MEMORYDB_ENDPOINT'],
            port=6379,
            decode_responses=True,
            socket_connect_timeout=5
        )
    return redis_client

def get_db_connection():
    secret_name = os.environ['SECRET_NAME']
    response = secretsmanager.get_secret_value(SecretId=secret_name)
    secret = json.loads(response['SecretString'])
    conn = psycopg2.connect(
        host=secret['host'],
        database=secret['dbname'],
        user=secret['username'],
        password=secret['password'],
        port=secret.get('port', 5432)
    )
    return conn

def get_embedding(text):
    body = json.dumps({"inputText": text})
    response = bedrock_runtime.invoke_model(
        modelId='amazon.titan-embed-text-v1',
        body=body,
        contentType='application/json',
        accept='application/json'
    )
    response_body = json.loads(response['body'].read())
    return response_body['embedding']

def check_semantic_cache(query, threshold=0.95):
    try:
        redis_conn = get_redis_client()
        query_hash = hashlib.sha256(query.encode()).hexdigest()
        cached_result = redis_conn.get(f"exact:{query_hash}")
        if cached_result:
            print("Cache hit: exact match")
            return json.loads(cached_result)
        return None
    except Exception as e:
        print(f"Cache check error: {str(e)}")
        return None

def store_in_cache(query, result):
    try:
        redis_conn = get_redis_client()
        query_hash = hashlib.sha256(query.encode()).hexdigest()
        redis_conn.setex(f"exact:{query_hash}", 3600, json.dumps(result))
        print("Stored result in cache")
    except Exception as e:
        print(f"Cache storage error: {str(e)}")

def find_relevant_tables(cursor, user_query, top_k=3):
    query_embedding = get_embedding(user_query)
    cursor.execute("""
        SELECT 
            table_name,
            table_description,
            1 - (embedding <=> %s::vector) as similarity
        FROM table_embeddings
        ORDER BY embedding <=> %s::vector
        LIMIT %s;
    """, (query_embedding, query_embedding, top_k))
    return cursor.fetchall()

def get_table_schema(cursor, table_names):
    cursor.execute("""
        SELECT 
            c.table_name,
            c.column_name,
            c.data_type,
            c.is_nullable,
            c.column_default
        FROM information_schema.columns c
        WHERE c.table_schema = 'public'
            AND c.table_name = ANY(%s)
        ORDER BY c.table_name, c.ordinal_position;
    """, (table_names,))
    return cursor.fetchall()

def generate_sql_query(user_query, table_schemas):
    schema_context = "Database Schema:\n"
    for table_name, columns in table_schemas.items():
        schema_context += f"\nTable: {table_name}\n"
        for col in columns:
            schema_context += f"  - {col['column_name']} ({col['data_type']})\n"
    
    prompt = f"""You are a SQL expert. Generate a PostgreSQL query based on the user's question.

{schema_context}

User Question: {user_query}

Important Instructions:
1. Generate ONLY a parameterized SQL query using $1, $2, etc. for any literal values
2. Return the SQL query and the parameter values separately
3. Use only SELECT statements (read-only)
4. Do not use DROP, DELETE, UPDATE, INSERT, or any write operations
5. Format your response as JSON with keys: "sql" and "parameters"

Example response format:
{{
    "sql": "SELECT * FROM properties WHERE city = $1 AND price < $2",
    "parameters": ["San Francisco", 1000000]
}}

Generate the SQL query now:"""

    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 2000,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1
    })
    
    response = bedrock_runtime.invoke_model(
        modelId='anthropic.claude-3-5-sonnet-20241022-v2:0',
        body=body,
        contentType='application/json',
        accept='application/json'
    )
    
    response_body = json.loads(response['body'].read())
    sql_response = response_body['content'][0]['text']
    
    if "```json" in sql_response:
        sql_response = sql_response.split("```json")[1].split("```")[0].strip()
    elif "```" in sql_response:
        sql_response = sql_response.split("```")[1].split("```")[0].strip()
    
    return json.loads(sql_response)

def execute_query(cursor, sql, parameters):
    cursor.execute(sql, parameters)
    return cursor.fetchall()

def interpret_results(user_query, sql, results):
    sample_results = results[:10] if len(results) > 10 else results
    prompt = f"""You are a helpful data analyst. Interpret the following SQL query results for the user.

User Question: {user_query}

SQL Query: {sql}

Query Results (showing {len(sample_results)} of {len(results)} rows):
{json.dumps(sample_results, indent=2, default=str)}

Provide a clear, concise natural language summary of these results that answers the user's question.
Focus on the key insights and relevant data points."""

    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1000,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3
    })
    
    response = bedrock_runtime.invoke_model(
        modelId='anthropic.claude-3-5-sonnet-20241022-v2:0',
        body=body,
        contentType='application/json',
        accept='application/json'
    )
    
    response_body = json.loads(response['body'].read())
    return response_body['content'][0]['text']

def handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    try:
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        user_query = body.get('query', '')
        if not user_query:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Query parameter is required'})
            }
        
        print(f"Processing query: {user_query}")
        cached_result = check_semantic_cache(user_query)
        if cached_result:
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'cached': True, **cached_result})
            }
        
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        print("Finding relevant tables")
        relevant_tables = find_relevant_tables(cursor, user_query)
        table_names = [row['table_name'] for row in relevant_tables]
        print(f"Relevant tables: {table_names}")
        
        schema_rows = get_table_schema(cursor, table_names)
        table_schemas = {}
        for row in schema_rows:
            table_name = row[0]
            if table_name not in table_schemas:
                table_schemas[table_name] = []
            table_schemas[table_name].append({
                'column_name': row[1],
                'data_type': row[2],
                'is_nullable': row[3],
                'column_default': row[4]
            })
        
        print("Generating SQL query")
        sql_data = generate_sql_query(user_query, table_schemas)
        sql_query = sql_data['sql']
        parameters = sql_data.get('parameters', [])
        print(f"Generated SQL: {sql_query}")
        
        print("Executing query")
        results = execute_query(cursor, sql_query, parameters)
        results_list = [dict(row) for row in results]
        print(f"Retrieved {len(results_list)} rows")
        
        print("Interpreting results")
        interpretation = interpret_results(user_query, sql_query, results_list)
        
        response_data = {
            'query': user_query,
            'sql': sql_query,
            'parameters': parameters,
            'results': results_list,
            'interpretation': interpretation,
            'row_count': len(results_list)
        }
        
        store_in_cache(user_query, response_data)
        cursor.close()
        conn.close()
        
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'cached': False, **response_data}, default=str)
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }
PYFILE
      fi

      # Create requirements.txt if it doesn't exist
      if [ ! -f requirements.txt ]; then
        echo "Creating requirements.txt..."
        cat > requirements.txt << 'REQFILE'
psycopg2-binary==2.9.9
redis==5.0.1
boto3==1.34.34
botocore==1.34.34
REQFILE
      fi

      echo "All required Python files created."
    EOT
  }
}

# Null resource to create terraform.tfvars if it doesn't exist
resource "null_resource" "create_tfvars" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -f terraform.tfvars ]; then
        echo "Creating terraform.tfvars file..."
        cat > terraform.tfvars << 'TFVARS'
aws_region         = "us-west-2"
project_name       = "text-to-sql-chatbot"
dataset_s3_bucket  = "your-s3-bucket-name"  # CHANGE THIS
db_master_username = "postgres"
db_name            = "housingdb"
TFVARS
        echo "Created terraform.tfvars - Please update dataset_s3_bucket with your bucket name!"
      else
        echo "terraform.tfvars already exists, skipping creation."
      fi
    EOT
  }

  depends_on = [null_resource.create_python_files]
}

# Null resource to build Lambda packages
resource "null_resource" "build_lambda_packages" {
  triggers = {
    # Use timestamp to always rebuild, or remove triggers entirely
    build_trigger = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Building Lambda deployment packages..."
      
      # Create directories
      mkdir -p lambda_packages/data_indexer
      mkdir -p lambda_packages/text_to_sql
      mkdir -p lambda_packages/layer/python
      
      # Install dependencies for Lambda layer
      echo "Installing dependencies for Lambda layer..."
      pip3 install \
        -r requirements.txt \
        -t lambda_packages/layer/python/ \
        --platform manylinux2014_x86_64 \
        --only-binary=:all: \
        --upgrade
      
      # Create layer zip
      echo "Creating Lambda layer package..."
      cd lambda_packages/layer
      zip -r ../../lambda_layer.zip python
      cd ../..
      
      # Copy data_indexer code
      echo "Packaging data_indexer function..."
      cp data_indexer.py lambda_packages/data_indexer/index.py
      cd lambda_packages/data_indexer
      zip -r ../../data_indexer.zip .
      cd ../..
      
      # Copy text_to_sql code
      echo "Packaging text_to_sql function..."
      cp text_to_sql.py lambda_packages/text_to_sql/index.py
      cd lambda_packages/text_to_sql
      zip -r ../../text_to_sql.zip .
      cd ../..
      
      echo "Done! Created Lambda packages."
    EOT
  }

  depends_on = [null_resource.create_tfvars]
}

# Lambda Layer for dependencies
resource "aws_lambda_layer_version" "dependencies" {
  filename            = "lambda_layer.zip"
  layer_name          = "${var.project_name}-dependencies"
  compatible_runtimes = ["python3.12"]
  description         = "Dependencies for text-to-sql functions"
  source_code_hash    = fileexists("lambda_layer.zip") ? filebase64sha256("lambda_layer.zip") : null

  depends_on = [null_resource.build_lambda_packages]

  lifecycle {
    create_before_destroy = true
  }
}

# Data Indexer Lambda Function
resource "aws_lambda_function" "data_indexer" {
  filename         = "data_indexer.zip"
  function_name    = "${var.project_name}-DataIndexerFunction"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 900
  memory_size      = 512
  source_code_hash = fileexists("data_indexer.zip") ? filebase64sha256("data_indexer.zip") : null

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
      AWS_REGION        = var.aws_region
    }
  }

  layers = [aws_lambda_layer_version.dependencies.arn]

  tags = {
    Name = "${var.project_name}-data-indexer"
  }

  depends_on = [null_resource.build_lambda_packages]
}

# Text to SQL Lambda Function
resource "aws_lambda_function" "text_to_sql" {
  filename         = "text_to_sql.zip"
  function_name    = "${var.project_name}-TextToSQLFunction"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 1024
  source_code_hash = fileexists("text_to_sql.zip") ? filebase64sha256("text_to_sql.zip") : null

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

  depends_on = [null_resource.build_lambda_packages]
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
