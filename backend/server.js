const express = require('express');
const cors = require('cors');
const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');

const app = express();

// Enable CORS first
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: false,
  optionsSuccessStatus: 204
}));

// Explicitly handle preflight
app.options('*', cors());

// Body parser
app.use(express.json());

// Request logging
app.use((req, res, next) => {
  console.log(`${req.method} ${req.url} from ${req.headers.origin || 'no origin'}`);
  next();
});

const bedrock = new BedrockRuntimeClient({ 
  region: 'us-east-1',
});

const DB_SCHEMA = `
Tables:
- employees (id, name, department, salary, hire_date)
- departments (id, name, budget)
- orders (id, customer_id, order_date, total_amount)
- products (id, name, price, category)
`;

app.post('/api/generate-sql', async (req, res) => {
  try {
    console.log('Processing SQL generation request');
    const { query } = req.body;

    if (!query) {
      return res.status(400).json({ error: 'Query is required' });
    }

    const prompt = `Convert this question to SQL. Database schema:
${DB_SCHEMA}

Question: ${query}

Respond with ONLY valid JSON in this exact format:
{"sql": "YOUR_SQL_HERE", "explanation": "what it does"}`;

    const command = new InvokeModelCommand({
      modelId: 'us.anthropic.claude-3-5-sonnet-20241022-v2:0',
      body: JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: 1024,
        messages: [{ role: 'user', content: prompt }]
      })
    });

    const response = await bedrock.send(command);
    const result = JSON.parse(new TextDecoder().decode(response.body));
    const content = result.content[0].text;
    
    console.log('Raw Claude response:', content);
    
    // Simply parse the content - Claude already provides valid JSON
    const parsed = JSON.parse(content.trim());
    
    console.log('Successfully generated SQL:', parsed);
    res.json(parsed);
  } catch (error) {
    console.error('Error details:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ 
      error: error.message,
      details: 'Failed to generate or parse SQL query'
    });
  }
});

app.get('/health', (req, res) => {
  console.log('Health check');
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Catch-all error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 8000;
const HOST = '0.0.0.0'; // Important: bind to all interfaces

app.listen(PORT, HOST, () => {
  console.log(`=================================`);
  console.log(`Server running on http://${HOST}:${PORT}`);
  console.log(`=================================`);
});
