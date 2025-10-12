import json
import os
import boto3
import psycopg2
from psycopg2.extras import execute_values

# Initialize AWS clients
bedrock_runtime = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-west-2'))
secretsmanager = boto3.client('secretsmanager', region_name=os.environ.get('AWS_REGION', 'us-west-2'))

def get_db_connection():
    """Get database connection using credentials from Secrets Manager"""
    secret_name = os.environ['SECRET_NAME']
    
    response = secretsmanager.get_secret_value(SecretId=secret_name)
    secret = json.loads(response['SecretString'])
    
    conn = psycopg2.connect(
        host=secret['host'],
        database=secret['dbname'],
        user=secret['username'],
        password=secret['password'],
        port=secret.get('port', 5432)
    )
    return conn

def create_embeddings_table(cursor):
    """Create table for storing embeddings if it doesn't exist"""
    cursor.execute("""
        CREATE EXTENSION IF NOT EXISTS vector;
    """)
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS table_embeddings (
            id SERIAL PRIMARY KEY,
            table_name VARCHAR(255),
            table_description TEXT,
            embedding vector(1536),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_table_embeddings_vector 
        ON table_embeddings USING ivfflat (embedding vector_cosine_ops)
        WITH (lists = 100);
    """)

def get_table_metadata(cursor):
    """Retrieve table metadata from information_schema"""
    cursor.execute("""
        SELECT 
            t.table_name,
            array_agg(
                c.column_name || ' (' || c.data_type || 
                CASE WHEN c.is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END || ')'
                ORDER BY c.ordinal_position
            ) as columns
        FROM information_schema.tables t
        JOIN information_schema.columns c 
            ON t.table_name = c.table_name 
            AND t.table_schema = c.table_schema
        WHERE t.table_schema = 'public'
            AND t.table_type = 'BASE TABLE'
            AND t.table_name != 'table_embeddings'
        GROUP BY t.table_name;
    """)
    
    return cursor.fetchall()

def generate_table_description(table_name, columns):
    """Generate a text description of the table for embedding"""
    column_list = ', '.join(columns)
    description = f"Table: {table_name}. Columns: {column_list}"
    return description

def get_embedding(text):
    """Generate embedding using Amazon Bedrock Titan Embeddings"""
    body = json.dumps({
        "inputText": text
    })
    
    response = bedrock_runtime.invoke_model(
        modelId='amazon.titan-embed-text-v1',
        body=body,
        contentType='application/json',
        accept='application/json'
    )
    
    response_body = json.loads(response['body'].read())
    embedding = response_body['embedding']
    
    return embedding

def store_embeddings(cursor, table_name, description, embedding):
    """Store the embedding in the database"""
    # Delete existing embedding for this table
    cursor.execute("""
        DELETE FROM table_embeddings WHERE table_name = %s;
    """, (table_name,))
    
    # Insert new embedding
    cursor.execute("""
        INSERT INTO table_embeddings (table_name, table_description, embedding)
        VALUES (%s, %s, %s);
    """, (table_name, description, embedding))

def handler(event, context):
    """Lambda handler function"""
    print("Starting data indexer function")
    
    conn = None
    try:
        # Connect to database
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Create embeddings table if it doesn't exist
        print("Creating embeddings table if needed")
        create_embeddings_table(cursor)
        conn.commit()
        
        # Get table metadata
        print("Retrieving table metadata")
        tables_metadata = get_table_metadata(cursor)
        
        print(f"Found {len(tables_metadata)} tables to process")
        
        # Process each table
        embeddings_created = 0
        for table_name, columns in tables_metadata:
            print(f"Processing table: {table_name}")
            
            # Generate description
            description = generate_table_description(table_name, columns)
            print(f"Description: {description}")
            
            # Generate embedding
            embedding = get_embedding(description)
            print(f"Generated embedding with dimension: {len(embedding)}")
            
            # Store in database
            store_embeddings(cursor, table_name, description, embedding)
            embeddings_created += 1
            
            print(f"Stored embedding for table: {table_name}")
        
        conn.commit()
        
        print(f"Successfully created {embeddings_created} embeddings")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully indexed {embeddings_created} tables',
                'tables_processed': embeddings_created
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        if conn:
            conn.rollback()
        raise e
        
    finally:
        if conn:
            cursor.close()
            conn.close()
