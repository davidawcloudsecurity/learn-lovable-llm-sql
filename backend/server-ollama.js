const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

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

    const prompt = `
Convert the user's question into a valid SQL query.

Database schema (use ONLY these tables and columns):
${DB_SCHEMA}

Rules:
- Do NOT invent tables or columns
- Use standard SQL
- Generate ONE SQL query only

Question:
${query}

Respond with ONLY valid JSON in this exact format:
{"sql":"SQL_QUERY_HERE","explanation":"brief description"}
`;

    const response = await fetch('http://localhost:11434/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'smollm3:latest', // 30GB+ model
        prompt: prompt,
        stream: false,
        options: {
          temperature: 0.1,
          top_p: 0.9,
          num_ctx: 4096
        }
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Ollama API error: ${response.status} - ${errorText}`);
    }

    const data = await response.json();
    console.log('Ollama response:', data);
    
    if (!data.response) {
      throw new Error('No response from Ollama model');
    }
    
    const content = data.response.trim();
    
    // Extract JSON from response
    const jsonMatch = content.match(/\{.*\}/s);
    if (!jsonMatch) {
      throw new Error('No valid JSON found in response');
    }
    
    const result = JSON.parse(jsonMatch[0]);
    
    // Format SQL for better readability
    if (result.sql) {
      result.sql = result.sql
        .replace(/\bSELECT\b/gi, '\nSELECT')
        .replace(/\bFROM\b/gi, '\nFROM')
        .replace(/\bWHERE\b/gi, '\nWHERE')
        .replace(/\bJOIN\b/gi, '\nJOIN')
        .replace(/\bON\b/gi, '\nON')
        .replace(/\bAND\b/gi, '\nAND')
        .replace(/\bOR\b/gi, '\nOR')
        .replace(/\bORDER BY\b/gi, '\nORDER BY')
        .replace(/\bGROUP BY\b/gi, '\nGROUP BY')
        .replace(/\bHAVING\b/gi, '\nHAVING')
        .trim();
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 8000;
app.listen(PORT, () => console.log(`Ollama server running on port ${PORT}`));
