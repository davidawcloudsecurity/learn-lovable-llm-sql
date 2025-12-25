output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main_vpc.id
}

output "frontend_public_ip" {
  description = "Public IP of frontend EC2"
  value       = aws_spot_instance_request.frontend.public_ip
}

output "frontend_url" {
  description = "Frontend URL"
  value       = "http://${aws_spot_instance_request.frontend.public_ip}"
}

output "backend_public_ip" {
  description = "Public IP of backend EC2"
  value       = aws_spot_instance_request.backend.public_ip
}

output "backend_api_url" {
  description = "Backend API URL"
  value       = "http://${aws_spot_instance_request.backend.public_ip}:8000"
}

output "frontend_instance_id" {
  description = "Frontend instance ID for SSM"
  value       = aws_spot_instance_request.frontend.spot_instance_id
}

output "backend_instance_id" {
  description = "Backend instance ID for SSM"
  value       = aws_spot_instance_request.backend.spot_instance_id
}

output "ssm_connect_frontend" {
  description = "SSM command to connect to frontend"
  value       = "aws ssm start-session --target ${aws_spot_instance_request.frontend.spot_instance_id}"
}

output "ssm_connect_backend" {
  description = "SSM command to connect to backend"
  value       = "aws ssm start-session --target ${aws_spot_instance_request.backend.spot_instance_id}"
}
