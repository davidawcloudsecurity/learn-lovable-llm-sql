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

    // Basic input validation
    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return res.status(400).json({ 
        error: 'Query is required and must be a non-empty string' 
      });
    }

    const prompt = `Convert this question to SQL. Database schema:
${DB_SCHEMA}

Question: ${query}

Respond with ONLY valid JSON in this exact format:
{"sql": "YOUR_SQL_HERE", "explanation": "what it does"}`;

    const response = await fetch('http://localhost:11434/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'smollm2:latest',
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
      throw new Error(`Ollama API error: ${response.status}`);
    }

    const data = await response.json();
    
    if (!data.response) {
      throw new Error('No response from Ollama model');
    }
    
    const content = data.response.trim();
    
    console.log('Raw LLM response:', content);
    
    // Extract JSON from response
    const jsonMatch = content.match(/\{.*\}/s);
    if (!jsonMatch) {
      throw new Error('No valid JSON found in response');
    }
    
    // Clean the JSON string
    let jsonString = jsonMatch[0]
      .replace(/[\x00-\x1F\x7F]/g, ' ')  // Replace control chars with spaces
      .replace(/\s+/g, ' ')             // Normalize whitespace
      .trim();
    
    console.log('Cleaned JSON:', jsonString);
    
    let result;
    try {
      result = JSON.parse(jsonString);
    } catch (parseError) {
      console.error('Parse error:', parseError.message);
      // Fallback: try to extract just the values
      const sqlMatch = content.match(/"sql"\s*:\s*"([^"]+)"/i);
      const explMatch = content.match(/"explanation"\s*:\s*"([^"]+)"/i);
      if (sqlMatch && explMatch) {
        result = { sql: sqlMatch[1], explanation: explMatch[1] };
      } else {
        throw new Error('Could not parse LLM response');
      }
    }
    
    // Validate result structure
    if (!result.sql || !result.explanation) {
      throw new Error('Response missing required fields');
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ 
      error: error.message || 'An unexpected error occurred'
    });
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 8000;
app.listen(PORT, () => console.log(`Ollama server running on port ${PORT}`));
