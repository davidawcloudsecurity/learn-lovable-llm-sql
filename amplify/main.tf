terraform {
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

# Amplify App
resource "aws_amplify_app" "text_to_sql_app" {
  name       = "text-to-sql-platform"
  repository = var.github_repository

  # Build settings for Vite React app
  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - npm ci
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: dist
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
  EOT

  # Environment variables for the app
  environment_variables = {
    AMPLIFY_DIFF_DEPLOY = "false"
    AMPLIFY_MONOREPO_APP_ROOT = "."
  }

  # Enable auto branch creation from repo
  enable_branch_auto_build = true
  enable_branch_auto_deletion = true

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

  enable_auto_build = true

  tags = {
    Name        = "main-branch"
    Environment = var.environment
  }
}

# Custom domain (optional)
resource "aws_amplify_domain_association" "custom_domain" {
  count       = var.custom_domain != "" ? 1 : 0
  app_id      = aws_amplify_app.text_to_sql_app.id
  domain_name = var.custom_domain

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = ""
  }

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = "www"
  }
}