output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main_vpc.id
}

output "frontend_public_ip" {
  description = "Public IP of frontend EC2"
  value       = aws_instance.frontend.public_ip
}

output "frontend_url" {
  description = "Frontend URL"
  value       = "http://${aws_instance.frontend.public_ip}"
}

output "backend_public_ip" {
  description = "Public IP of backend EC2"
  value       = aws_instance.backend.public_ip
}

output "backend_api_url" {
  description = "Backend API URL"
  value       = "http://${aws_instance.backend.public_ip}:8000"
}

output "ssh_frontend" {
  description = "SSH command for frontend"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.frontend.public_ip}"
}

output "ssh_backend" {
  description = "SSH command for backend"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.backend.public_ip}"
}

