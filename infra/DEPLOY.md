# Deployment Guide

## What You Get

- **Frontend EC2**: Ubuntu with Node.js, Nginx (ports 80, 5173)
- **Backend EC2**: Ubuntu with Node.js, IAM role for Bedrock (port 8000)
- **VPC**: Public subnet with internet gateway
- **Security Groups**: Separate for frontend and backend

---

## Prerequisites

1. **AWS CLI configured**: `aws configure`
2. **Terraform installed**: `terraform --version`
3. **SSH Key Pair**: Create one first

```bash
# Create SSH key
aws ec2 create-key-pair \
  --key-name my-text-to-sql-key \
  --query 'KeyMaterial' \
  --output text > my-text-to-sql-key.pem

chmod 400 my-text-to-sql-key.pem
```

4. **Enable Bedrock Models** (AWS Console):
   - Go to Bedrock → Model access
   - Enable: `anthropic.claude-3-5-sonnet-20241022-v2:0`

---

## Deploy Infrastructure

```bash
cd infra

# Initialize Terraform
terraform init

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
aws_region = "us-east-1"
key_name   = "my-text-to-sql-key"
EOF

# Deploy
terraform apply

# Save outputs
terraform output > outputs.txt
```

---

## Setup Backend

```bash
# Get backend IP
BACKEND_IP=$(terraform output -raw backend_public_ip)

# SSH to backend
ssh -i my-text-to-sql-key.pem ubuntu@$BACKEND_IP

# On backend EC2:
cd /home/ubuntu
git clone <your-repo-url> app
cd app/backend
npm install

# Start backend
export AWS_REGION=us-east-1
npm start

# Or use PM2 for production
npm install -g pm2
pm2 start server.js --name backend
pm2 startup
pm2 save
```

---

## Setup Frontend

```bash
# Get frontend IP
FRONTEND_IP=$(terraform output -raw frontend_public_ip)

# SSH to frontend
ssh -i my-text-to-sql-key.pem ubuntu@$FRONTEND_IP

# On frontend EC2:
cd /home/ubuntu
git clone <your-repo-url> app
cd app

# Update API URL in code
BACKEND_IP="<backend-ip-here>"
cat > .env.production <<EOF
VITE_API_URL=http://$BACKEND_IP:8000
EOF

# Build and deploy
npm install
npm run build

# Copy to nginx
sudo cp -r dist/* /var/www/html/
sudo systemctl restart nginx
```

---

## Test

```bash
# Test backend
BACKEND_IP=$(terraform output -raw backend_public_ip)
curl -X POST http://$BACKEND_IP:8000/api/generate-sql \
  -H "Content-Type: application/json" \
  -d '{"query":"Show top 10 employees by salary"}'

# Test frontend
FRONTEND_IP=$(terraform output -raw frontend_public_ip)
echo "Open browser: http://$FRONTEND_IP"
```

---

## Architecture

```
Internet
   │
   ├─→ Frontend EC2 (port 80/5173)
   │   └─ React app + Nginx
   │
   └─→ Backend EC2 (port 8000)
       └─ Node.js Express + Bedrock
```

---

## Costs (Approximate)

- 2x t3.small EC2: ~$30/month
- Bedrock API: ~$0.003 per 1K tokens
- Data transfer: Minimal

**Total**: ~$30-40/month

---

## Cleanup

```bash
terraform destroy
aws ec2 delete-key-pair --key-name my-text-to-sql-key
rm my-text-to-sql-key.pem
```
