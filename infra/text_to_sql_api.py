#!/usr/bin/env python3
"""
Text-to-SQL API using AWS Bedrock Claude
Run on EC2: uvicorn text_to_sql_api:app --host 0.0.0.0 --port 8000
"""

import json
import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import boto3

app = FastAPI(title="Text-to-SQL API")

# CORS for frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Bedrock client
bedrock = boto3.client(
    service_name="bedrock-runtime",
    region_name=os.environ.get("AWS_REGION", "us-east-1")
)

# Database schema context (update with your actual schema)
DB_SCHEMA = """
Tables:
- employees (id, name, department, salary, hire_date)
- departments (id, name, budget)

Relationships:
- employees.department references departments.name
"""

class QueryRequest(BaseModel):
    query: str

class QueryResponse(BaseModel):
    sql: str
    explanation: str

@app.post("/generate-sql", response_model=QueryResponse)
async def generate_sql(request: QueryRequest):
    """Convert natural language to SQL using Bedrock Claude"""
    
    prompt = f"""You are a SQL expert. Convert the following natural language question into a PostgreSQL query.

Database Schema:
{DB_SCHEMA}

User Question: {request.query}

Respond with ONLY a JSON object in this exact format:
{{"sql": "YOUR_SQL_QUERY_HERE", "explanation": "Brief explanation of what the query does"}}

Important:
- Use PostgreSQL syntax
- Only use tables and columns from the schema above
- Make the query efficient and correct
"""

    try:
        response = bedrock.invoke_model(
            modelId="anthropic.claude-3-sonnet-20240229-v1:0",
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 1024,
                "messages": [
                    {"role": "user", "content": prompt}
                ]
            })
        )
        
        response_body = json.loads(response["body"].read())
        content = response_body["content"][0]["text"]
        
        # Parse JSON response
        result = json.loads(content)
        return QueryResponse(
            sql=result.get("sql", ""),
            explanation=result.get("explanation", "")
        )
        
    except json.JSONDecodeError:
        # If Claude didn't return valid JSON, try to extract SQL
        return QueryResponse(
            sql=content.strip(),
            explanation="Generated SQL query"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
