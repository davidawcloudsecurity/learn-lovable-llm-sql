Based on the AWS blog post you shared, here's how to use this `main.tf`:

## Step-by-Step Deployment Guide

### 1. **Prerequisites Setup**

```bash
# Install required tools
# - AWS CLI configured with credentials
# - Terraform >= 1.0
# - Python 3.12 with pip

# Enable Bedrock model access in us-west-2
# Go to AWS Console -> Bedrock -> Model access
# Enable:
# - anthropic.claude-3-5-sonnet-20241022-v2:0
# - amazon.titan-embed-text-v1
```

### 2. **Download and Prepare Dataset**

```bash
# Download from Kaggle
# https://www.kaggle.com/datasets/polartech/500000-us-homes-data-for-sale-properties

# Create S3 bucket and upload
aws s3 mb s3://your-unique-bucket-name
aws s3 cp "600k US Housing Properties.csv" s3://your-unique-bucket-name/
```

### 3. **Deploy Infrastructure with Terraform**

```bash
# Create project directory
mkdir text-to-sql-chatbot
cd text-to-sql-chatbot

# Save the main.tf (from my artifact)
# The main.tf will automatically create:
# - data_indexer.py
# - text_to_sql.py
# - requirements.txt
# - terraform.tfvars

# Initialize Terraform
terraform init

# Deploy (takes 20-30 minutes for RDS and MemoryDB)
terraform apply

# After first apply, edit terraform.tfvars with your bucket name
nano terraform.tfvars
# Change: dataset_s3_bucket = "your-unique-bucket-name"

# Apply again with correct bucket
terraform apply
```

### 4. **Load Data into RDS**

```bash
# Get outputs
BASTION_ID=$(terraform output -raw bastion_instance_id)
SECRET_NAME=$(terraform output -raw db_secret_name)

# Connect to bastion via SSM
aws ssm start-session --target $BASTION_ID

# On bastion host, run:
export SECRET_NAME="text-to-sql-chatbot-db-credentials"

# Download dataset from S3
aws s3 cp s3://your-unique-bucket-name/600k\ US\ Housing\ Properties.csv /tmp/housing.csv

# Install Python dependencies
sudo yum install -y python3-pip
pip3 install psycopg2-binary boto3 pandas

# Create data loading script
cat > /tmp/load_data.py << 'EOF'
import json
import boto3
import psycopg2
import pandas as pd
import os

# Get DB credentials
secretsmanager = boto3.client('secretsmanager')
secret = json.loads(secretsmanager.get_secret_value(SecretId=os.environ['SECRET_NAME'])['SecretString'])

# Connect to database
conn = psycopg2.connect(
    host=secret['host'],
    database=secret['dbname'],
    user=secret['username'],
    password=secret['password']
)
cursor = conn.cursor()

# Create table
cursor.execute("""
    CREATE TABLE IF NOT EXISTS properties (
        id SERIAL PRIMARY KEY,
        street VARCHAR(500),
        city VARCHAR(100),
        state VARCHAR(2),
        zip_code VARCHAR(10),
        beds INTEGER,
        baths DECIMAL(3,1),
        sqft INTEGER,
        price DECIMAL(15,2),
        price_per_sqft DECIMAL(10,2),
        latitude DECIMAL(10,8),
        longitude DECIMAL(11,8),
        property_type VARCHAR(50),
        year_built INTEGER
    );
""")
conn.commit()

# Load CSV
print("Loading CSV file...")
df = pd.read_csv('/tmp/housing.csv')

# Map CSV columns to database columns (adjust based on actual CSV structure)
batch_size = 1000
total_rows = len(df)

for i in range(0, total_rows, batch_size):
    batch = df.iloc[i:i+batch_size]
    
    for _, row in batch.iterrows():
        try:
            cursor.execute("""
                INSERT INTO properties (
                    street, city, state, zip_code, beds, baths, sqft, 
                    price, price_per_sqft, latitude, longitude, 
                    property_type, year_built
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                str(row.get('street', '')), str(row.get('city', '')), 
                str(row.get('state', '')), str(row.get('zip_code', '')),
                int(row.get('beds', 0)) if pd.notna(row.get('beds')) else None,
                float(row.get('baths', 0)) if pd.notna(row.get('baths')) else None,
                int(row.get('sqft', 0)) if pd.notna(row.get('sqft')) else None,
                float(row.get('price', 0)) if pd.notna(row.get('price')) else None,
                float(row.get('price_per_sqft', 0)) if pd.notna(row.get('price_per_sqft')) else None,
                float(row.get('latitude', 0)) if pd.notna(row.get('latitude')) else None,
                float(row.get('longitude', 0)) if pd.notna(row.get('longitude')) else None,
                str(row.get('property_type', '')),
                int(row.get('year_built', 0)) if pd.notna(row.get('year_built')) else None
            ))
        except Exception as e:
            print(f"Error inserting row: {e}")
            continue
    
    conn.commit()
    print(f"Loaded {min(i+batch_size, total_rows)}/{total_rows} rows")

cursor.close()
conn.close()
print("Data loading complete!")
EOF

# Run the script
python3 /tmp/load_data.py

# Exit bastion
exit
```

### 5. **Create Embeddings**

```bash
# Invoke Data Indexer Lambda
aws lambda invoke \
    --function-name $(terraform output -raw data_indexer_function_name) \
    --region us-west-2 \
    response.json

cat response.json
```

### 6. **Test the Text-to-SQL Function**

```bash
# Test query
aws lambda invoke \
    --function-name $(terraform output -raw text_to_sql_function_name) \
    --region us-west-2 \
    --payload '{"query":"What are the top 5 most expensive properties in San Francisco?"}' \
    response.json

cat response.json | jq .
```

### 7. **Access via API Gateway**

```bash
# Get API endpoint
API_URL=$(terraform output -raw api_gateway_url)

# Test with curl
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{"query":"What are the top 5 most expensive properties in San Francisco?"}'
```

### 8. **Optional: Streamlit Frontend**

```bash
# Create streamlit app locally
cat > streamlit_app.py << 'EOF'
import streamlit as st
import requests
import json

st.title("🏠 AI-Powered Housing Data Chatbot")

# Get from terraform output
api_endpoint = st.text_input("API Endpoint", value="YOUR_API_URL_HERE")

user_query = st.text_area("Ask a question about housing data:", 
    placeholder="e.g., What are the top 5 most expensive properties in San Francisco?")

if st.button("Submit Query"):
    if user_query:
        with st.spinner("Processing..."):
            response = requests.post(
                api_endpoint,
                json={"query": user_query}
            )
            
            if response.status_code == 200:
                result = response.json()
                
                st.subheader("📊 Answer")
                st.write(result.get("interpretation"))
                
                with st.expander("View Generated SQL"):
                    st.code(result.get("sql"), language="sql")
                
                with st.expander("View Results"):
                    st.json(result.get("results")[:10])
                
                st.info(f"Returned {result.get('row_count')} rows")
            else:
                st.error(f"Error: {response.text}")
EOF

# Run Streamlit
pip install streamlit requests
streamlit run streamlit_app.py
```

### 9. **Cleanup**

```bash
# Destroy all resources
terraform destroy
```

## Key Differences from AWS CDK Version

| Feature | AWS Blog (CDK) | This Terraform Version |
|---------|----------------|------------------------|
| Infrastructure as Code | AWS CDK (TypeScript/Python) | Terraform (HCL) |
| File Creation | Manual | Automated via null_resource |
| Lambda Packaging | Separate build script | Built-in null_resource |
| Configuration | CDK context/parameters | terraform.tfvars |

**Commit message:**
```
docs: add complete deployment guide for text-to-SQL chatbot using Terraform
```
