const express = require('express');
const cors = require('cors');
const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');

const app = express();
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: false
}));
app.use(express.json());

const bedrock = new BedrockRuntimeClient({ 
  region: process.env.AWS_REGION || 'us-east-1',
  // Will automatically use EC2 instance profile credentials
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
    const { query } = req.body;

    const prompt = `Convert this question to SQL. Database schema:
${DB_SCHEMA}

Question: ${query}

Respond with JSON: {"sql": "YOUR_SQL_HERE", "explanation": "what it does"}`;

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
    
    const parsed = JSON.parse(content);
    res.json(parsed);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 8000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
