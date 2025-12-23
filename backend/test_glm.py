from transformers import AutoTokenizer, AutoModelForCausalLM
import json

# Load model and tokenizer
print("Loading GLM-4.7 model...")
tokenizer = AutoTokenizer.from_pretrained("zai-org/GLM-4.7")
model = AutoModelForCausalLM.from_pretrained("zai-org/GLM-4.7")
print("Model loaded successfully!")

# Database schema
DB_SCHEMA = """
Tables:
- employees (id, name, department, salary, hire_date)
- departments (id, name, budget)
- orders (id, customer_id, order_date, total_amount)
- products (id, name, price, category)
"""

def generate_sql(question):
    prompt = f"""Convert this question to SQL. Database schema:
{DB_SCHEMA}

Question: {question}

Respond with ONLY valid JSON in this exact format:
{{"sql": "YOUR_SQL_HERE", "explanation": "what it does"}}"""

    messages = [{"role": "user", "content": prompt}]
    
    inputs = tokenizer.apply_chat_template(
        messages,
        add_generation_prompt=True,
        tokenize=True,
        return_dict=True,
        return_tensors="pt",
    ).to(model.device)

    outputs = model.generate(**inputs, max_new_tokens=200, temperature=0.1)
    response = tokenizer.decode(outputs[0][inputs["input_ids"].shape[-1]:])
    
    return response.strip()

# Test the model
if __name__ == "__main__":
    question = "Show all employees with salary greater than 50000"
    print(f"\nQuestion: {question}")
    print("Generating SQL...")
    
    result = generate_sql(question)
    print(f"\nResponse: {result}")
