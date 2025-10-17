terraform {
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

# S3 bucket for build artifacts
resource "aws_s3_bucket" "build_artifacts" {
  bucket = "${var.project_name}-build-artifacts-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "build-artifacts"
    Environment = var.environment
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Build and upload to S3
resource "null_resource" "build_and_upload" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ..
      npm ci
      npm run build
      aws s3 sync dist/ s3://${aws_s3_bucket.build_artifacts.bucket}/
    EOT
  }

  depends_on = [aws_s3_bucket.build_artifacts]
}

# Amplify App (without repository)
resource "aws_amplify_app" "text_to_sql_app" {
  name = "text-to-sql-platform"

  tags = {
    Name        = "text-to-sql-platform"
    Environment = var.environment
  }
}

# Main branch
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.text_to_sql_app.id
  branch_name = "main"

  framework = "React"
  stage     = "PRODUCTION"

  tags = {
    Name        = "main-branch"
    Environment = var.environment
  }
}