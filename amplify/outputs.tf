output "amplify_app_id" {
  description = "Amplify App ID"
  value       = aws_amplify_app.text_to_sql_app.id
}

output "amplify_app_arn" {
  description = "Amplify App ARN"
  value       = aws_amplify_app.text_to_sql_app.arn
}

output "default_domain" {
  description = "Default Amplify domain"
  value       = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.text_to_sql_app.default_domain}"
}

output "s3_bucket_name" {
  description = "S3 bucket containing build artifacts"
  value       = aws_s3_bucket.build_artifacts.bucket
}

output "s3_bucket_url" {
  description = "S3 bucket URL for manual Amplify deployment"
  value       = "s3://${aws_s3_bucket.build_artifacts.bucket}"
}