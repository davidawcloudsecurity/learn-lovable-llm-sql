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
  region: process.env.AWS_REGION || 'us-east-1',
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

Respond ONLY with valid JSON in this exact format (no markdown, no code blocks):
{"sql": "YOUR_SQL_HERE", "explanation": "what it does"}

Important: Keep SQL on a single line or use \\n for newlines in the JSON string.`;

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
    
    // Clean up the response - remove markdown code blocks if present
    let cleanedContent = content.trim();
    
    // Remove markdown JSON code blocks
    cleanedContent = cleanedContent.replace(/```json\s*/g, '');
    cleanedContent = cleanedContent.replace(/```\s*/g, '');
    
    // Extract JSON object
    const jsonMatch = cleanedContent.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.error('No valid JSON found in response:', cleanedContent);
      throw new Error('No valid JSON found in response');
    }
    
    let jsonString = jsonMatch[0];
    
    // Replace actual newlines with \n in the JSON string
    // This fixes the "Bad control character" error
    jsonString = jsonString.replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t');
    
    console.log('Cleaned JSON string:', jsonString);
    
    const parsed = JSON.parse(jsonString);
    
    // Clean up the sql field to restore proper formatting for display
    if (parsed.sql) {
      parsed.sql = parsed.sql.replace(/\\n/g, '\n').replace(/\\t/g, '\t');
    }
    
    console.log('Successfully generated SQL:', parsed);
    res.json(parsed);
  } catch (error) {
    console.error('Error details:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ 
      error: error.message,
      details: 'Failed to parse AI response. Check server logs.'
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
  console.log(`Accessible at http://10.0.1.150:${PORT}`);
  console.log(`Health check: http://10.0.1.150:${PORT}/health`);
  console.log(`=================================`);
});
