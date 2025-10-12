#!/bin/bash
set -e

# Update system
yum update -y

# Install PostgreSQL client and jq for JSON parsing
yum install -y postgresql jq

# Get RDS credentials from Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id ${rds_secret_arn} --region ${region} --query SecretString --output text)

# Parse credentials
RDS_HOST=$(echo $SECRET_JSON | jq -r .host)
RDS_PORT=$(echo $SECRET_JSON | jq -r .port)
RDS_USERNAME=$(echo $SECRET_JSON | jq -r .username)
RDS_PASSWORD=$(echo $SECRET_JSON | jq -r .password)
RDS_DBNAME=$(echo $SECRET_JSON | jq -r .dbname)

# Wait for RDS to be ready
echo "Waiting for RDS to be ready..."
until pg_isready -h $RDS_HOST -p $RDS_PORT -U $RDS_USERNAME; do
  echo "Waiting for database connection..."
  sleep 10
done

# Initialize database
echo "Initializing database..."

# Create tables and insert sample data
psql "postgresql://$RDS_USERNAME:$RDS_PASSWORD@$RDS_HOST:$RDS_PORT/$RDS_DBNAME" << EOF
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    department VARCHAR(50),
    salary DECIMAL(10,2),
    hire_date DATE
);

CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50),
    budget DECIMAL(12,2)
);

-- Insert sample data
INSERT INTO departments (name, budget) VALUES 
('Engineering', 1000000),
('Sales', 500000),
('Marketing', 300000)
ON CONFLICT DO NOTHING;

INSERT INTO employees (name, department, salary, hire_date) VALUES
('John Doe', 'Engineering', 75000, '2022-01-15'),
('Jane Smith', 'Sales', 65000, '2021-03-20'),
('Bob Johnson', 'Engineering', 80000, '2020-11-10'),
('Alice Brown', 'Marketing', 60000, '2023-02-01')
ON CONFLICT DO NOTHING;

-- Verify data was inserted
SELECT 'Departments count: ' || COUNT(*) FROM departments;
SELECT 'Employees count: ' || COUNT(*) FROM employees;
EOF

echo "Database initialization completed successfully!"

# Optional: Install and setup SSM agent (usually pre-installed on Amazon Linux 2)
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Create a completion marker
echo "RDS setup completed at $(date)" > /home/ec2-user/setup-complete.txt
