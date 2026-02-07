terraform {
  backend "s3" {
    bucket         = "learn-lovable-llm-sql-2338-tfm-state"
    key            = "project1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
