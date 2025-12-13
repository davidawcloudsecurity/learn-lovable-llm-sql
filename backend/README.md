# Backend Setup

## Option 1: AWS Bedrock (Recommended)

### Prerequisites
1. AWS account with Bedrock access enabled
2. AWS credentials configured (`aws configure`)
3. Enable Claude model in AWS Console → Bedrock → Model access

### Run Locally
```bash
cd backend
npm install
export AWS_REGION=us-east-1
npm start
```

### Deploy to EC2
```bash
# On EC2 instance (Amazon Linux 2023 or Ubuntu)
sudo yum install -y nodejs npm  # or: sudo apt install nodejs npm
cd /home/ec2-user/backend
npm install
export AWS_REGION=us-east-1
npm start
```

### Install AWSCLIv2
```
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```
### List available models:
```
aws bedrock list-foundation-models --region us-east-1
```
### Get specific model details:
```
aws bedrock get-foundation-model \
  --model-identifier us.anthropic.claude-3-5-sonnet-20241022-v2:0 \
  --region us-east-1
```
### Invoke model (like your server does):
```
aws bedrock-runtime invoke-model \
  --model-id us.anthropic.claude-3-5-sonnet-20241022-v2:0 \
  --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":1024,"messages":[{"role":"user","content":"Convert to SQL: Show all employees"}]}' \
  --cli-binary-format raw-in-base64-out \
  --region us-east-1 \
  output.json
```
### Check model access:
````
aws bedrock get-model-invocation-logging-configuration --region us-east-1
```

### List model customization jobs:
````
aws bedrock list-custom-models --region us-east-1
```
### Test with streaming (like chat):
```
aws bedrock-runtime invoke-model-with-response-stream \
  --model-id us.anthropic.claude-3-5-sonnet-20241022-v2:0 \
  --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":100,"messages":[{"role":"user","content":"Hello"}]}' \
  --cli-binary-format raw-in-base64-out \
  --region us-east-1 \
  stream-output.json
```

---

## Option 2: OpenAI API

### Prerequisites
1. OpenAI API key from platform.openai.com

### Run Locally
```bash
cd backend
npm install openai
export OPENAI_API_KEY=sk-...
node server-openai.js
```

---

## API Endpoints

**POST /api/generate-sql**
```json
Request:  {"query": "Show top 10 employees by salary"}
Response: {"sql": "SELECT * FROM...", "explanation": "..."}
```

**GET /health**
```json
Response: {"status": "ok"}
```

---

## Connect Frontend

Update `src/components/ChatInterface.tsx`:
```typescript
const response = await fetch('http://localhost:8000/api/generate-sql', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ query: input })
});
const data = await response.json();
```

---

## EC2 Setup (Production)

1. **Launch EC2**: t3.small or larger
2. **Security Group**: Allow port 8000 from frontend IP
3. **Install Node.js**: `curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -`
4. **IAM Role**: Attach role with `bedrock:InvokeModel` permission
5. **Run with PM2**:
```bash
npm install -g pm2
pm2 start server.js
pm2 startup
pm2 save
```
