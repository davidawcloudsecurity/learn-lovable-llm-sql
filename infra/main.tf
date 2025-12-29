terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# Create Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Create Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group for Frontend (React)
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Security group for frontend EC2"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "frontend-sg"
  }
}

# Security Group for Backend (Node.js)
resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Security group for backend EC2"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 8000
    to_port     = 8000
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
    Name = "backend-sg"
  }
}

# IAM Role for Frontend
resource "aws_iam_role" "frontend_role" {
  name = "frontend-role"

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

resource "aws_iam_instance_profile" "frontend_profile" {
  name = "frontend-instance-profile"
  role = aws_iam_role.frontend_role.name
}

resource "aws_iam_role_policy_attachment" "frontend_ssm_policy" {
  role       = aws_iam_role.frontend_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Role for Backend (Bedrock access)
resource "aws_iam_role" "backend_role" {
  name = "backend-bedrock-role"

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

resource "aws_iam_role_policy" "bedrock_policy" {
  name = "bedrock-access"
  role = aws_iam_role.backend_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "backend_profile" {
  name = "backend-instance-profile"
  role = aws_iam_role.backend_role.name
}

resource "aws_iam_role_policy_attachment" "backend_ssm_policy" {
  role       = aws_iam_role.backend_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Frontend EC2 Instance
resource "aws_spot_instance_request" "frontend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.frontend_profile.name
  
  spot_price                      = "0.02"
  wait_for_fulfillment           = true
  spot_type                      = "persistent"
  instance_interruption_behavior = "stop"

  user_data = <<-EOF
              #!/bin/bash
              apt update
              apt install -y nginx git curl
              
              # Install Node.js 18 via NodeSource
              curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
              apt install -y nodejs
              
              # Clone repo (replace with your repo URL)
              cd /opt
              git clone https://github.com/davidawcloudsecurity/learn-lovable-llm-sql.git app
              cd app
              npm install
              npm run build
              
              # Configure nginx to serve React app
              cat > /etc/nginx/sites-available/default <<'NGINX'
              server {
                listen 80;
                root /opt/app/dist;
                index index.html;
                
                # Proxy API requests to backend
                location /api/ {
                  proxy_pass http://${aws_spot_instance_request.backend.private_ip}:8000;
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                }
                
                # Serve React app
                location / {
                  try_files $uri $uri/ /index.html;
                }
              }
              NGINX
              
              systemctl restart nginx
              EOF

  tags = {
    Name = "frontend-instance"
  }
}

# Backend EC2 Instance
resource "aws_spot_instance_request" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "m5.xlarge"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.backend_profile.name

  spot_price                     = "0.09"
  wait_for_fulfillment           = true
  spot_type                      = "persistent"
  instance_interruption_behavior = "stop"

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
    encrypted   = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt update
              apt install -y git curl
              
              # Install Node.js 18 via NodeSource
              curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
              apt install -y nodejs
              
              # Clone repo (replace with your repo URL)
              cd /opt
              git clone https://github.com/davidawcloudsecurity/learn-lovable-llm-sql.git app
              cd app/backend
              npm install
              
              # Install PM2 for process management
              npm install -g pm2
              
              # Start backend (uncomment after setup)
              # export AWS_REGION=us-east-1
              # pm2 start server.js
              # pm2 startup
              # pm2 save
              EOF

  tags = {
    Name = "backend-instance"
  }
}

# Get latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
