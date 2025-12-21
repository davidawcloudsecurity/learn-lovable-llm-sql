import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Card } from "@/components/ui/card";
import { Send, Copy, Check, Loader2, Database } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

interface Message {
  id: string;
  type: "user" | "assistant";
  text: string;
  sql?: string;
}

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api';

const ChatInterface = () => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const { toast } = useToast();

  // Hardcoded example queries
  const hardcodedQueries = [
    "Show me all customers who made purchases in the last 30 days",
    "Find the top 10 products by revenue this month",
    "List employees with salary above average in the sales department",
  ];

  const [exampleQueries, setExampleQueries] = useState(hardcodedQueries);
  const [useApiQueries, setUseApiQueries] = useState(false);

  const fetchExampleQueries = async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/example-queries`);
      if (response.ok) {
        const data = await response.json();
        return data.queries || hardcodedQueries;
      }
    } catch (error) {
      console.error('Failed to fetch example queries:', error);
    }
    return hardcodedQueries;
  };

  const toggleQuerySource = async () => {
    if (!useApiQueries) {
      const apiQueries = await fetchExampleQueries();
      setExampleQueries(apiQueries);
    } else {
      setExampleQueries(hardcodedQueries);
    }
    setUseApiQueries(!useApiQueries);
  };

  const hardcodedResponses = {
    "Show me all customers who made purchases in the last 30 days": {
      sql: "SELECT * FROM customers c\nWHERE EXISTS (\n  SELECT 1 FROM orders o\n  WHERE o.customer_id = c.id\n  AND o.order_date >= CURRENT_DATE - INTERVAL 30 DAY\n);",
      explanation: "This query finds all customers who have made at least one purchase in the last 30 days by checking for existing orders within that timeframe."
    },
    "Find the top 10 products by revenue this month": {
      sql: "SELECT p.name, SUM(oi.quantity * oi.price) as revenue\nFROM products p\nJOIN order_items oi ON p.id = oi.product_id\nJOIN orders o ON oi.order_id = o.id\nWHERE MONTH(o.order_date) = MONTH(CURRENT_DATE)\nAND YEAR(o.order_date) = YEAR(CURRENT_DATE)\nGROUP BY p.id, p.name\nORDER BY revenue DESC\nLIMIT 10;",
      explanation: "This query calculates total revenue for each product this month and returns the top 10 highest earning products."
    },
    "List employees with salary above average in the sales department": {
      sql: "SELECT e.name, e.salary\nFROM employees e\nWHERE e.department = 'sales'\nAND e.salary > (\n  SELECT AVG(salary)\n  FROM employees\n  WHERE department = 'sales'\n);",
      explanation: "This query finds all sales department employees whose salary exceeds the average salary within their department."
    }
  };

  const generateSQLResponse = async (query: string): Promise<{sql: string, explanation: string}> => {
    const response = await fetch(`/api/generate-sql`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    return {
      sql: data.sql,
      explanation: data.explanation
    };
  };

  const handleSubmit = async (queryText?: string, isExample = false) => {
    const query = queryText || input.trim();
    if (!query) return;

    const userMessageId = Date.now().toString();
    const userMessage: Message = {
      id: userMessageId,
      type: "user",
      text: query,
    };

    setMessages((prev) => [...prev, userMessage]);
    setInput("");
    setIsLoading(true);

    try {
      let response;

      if (isExample && !useApiQueries && hardcodedResponses[query as keyof typeof hardcodedResponses]) {
        response = hardcodedResponses[query as keyof typeof hardcodedResponses];
      } else {
        response = await generateSQLResponse(query);
      }
      
      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        type: "assistant",
        text: response.explanation,
        sql: response.sql,
      };
      setMessages((prev) => [...prev, assistantMessage]);
      
      toast({
        title: "Query Generated",
        description: "Your SQL query is ready to use",
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to generate SQL query",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleCopy = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
    
    toast({
      title: "Copied!",
      description: "SQL query copied to clipboard",
    });
  };

  return (
    <section className="py-20 px-4 bg-background">
      <div className="container mx-auto max-w-4xl">
        <div className="text-center mb-12">
          <h2 className="text-4xl font-bold mb-4">Try It Yourself</h2>
          <p className="text-xl text-muted-foreground">
            Ask a question in plain English and watch it transform into SQL
          </p>
        </div>

        {/* Example queries */}
        {messages.length === 0 && (
          <div className="mb-8 space-y-3">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm font-medium text-muted-foreground">Try these examples:</p>
              <Button
                variant="outline"
                size="sm"
                onClick={toggleQuerySource}
                className="text-xs"
              >
                {useApiQueries ? 'API' : 'Hardcoded'}
              </Button>
            </div>
            {exampleQueries.map((query, idx) => (
              <button
                key={idx}
                onClick={() => handleSubmit(query, true)}
                className="w-full text-left p-4 rounded-lg border-2 border-border hover:border-primary/50 hover:bg-secondary/50 transition-all duration-300 group"
              >
                <div className="flex items-start gap-3">
                  <Database className="h-5 w-5 text-primary mt-0.5 group-hover:text-accent transition-colors" />
                  <span className="text-sm">{query}</span>
                </div>
              </button>
            ))}
          </div>
        )}

        {/* Chat messages */}
        <div className="space-y-6 mb-6 min-h-[200px]">
          {messages.map((message) => (
            <Card
              key={message.id}
              className={`p-6 ${
                message.type === "user"
                  ? "bg-primary/5 border-primary/20"
                  : "bg-card shadow-elegant"
              }`}
            >
              <div className="flex items-start gap-4">
                <div
                  className={`flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center ${
                    message.type === "user"
                      ? "bg-primary text-primary-foreground"
                      : "bg-accent text-accent-foreground"
                  }`}
                >
                  {message.type === "user" ? "U" : "AI"}
                </div>
                
                <div className="flex-1 space-y-3">
                  <p className="text-sm leading-relaxed">{message.text}</p>
                  
                  {message.sql && (
                    <div className="relative">
                      <pre className="bg-muted border border-border p-4 rounded-lg overflow-x-auto text-sm font-mono shadow-sm whitespace-pre-wrap break-words">
                        <code className="block">{message.sql}</code>
                      </pre>
                      
                      <Button
                        size="sm"
                        variant="ghost"
                        className="absolute top-2 right-2"
                        onClick={() => handleCopy(message.sql!, message.id)}
                      >
                        {copiedId === message.id ? (
                          <Check className="h-4 w-4 text-accent" />
                        ) : (
                          <Copy className="h-4 w-4" />
                        )}
                      </Button>
                    </div>
                  )}
                </div>
              </div>
            </Card>
          ))}
          
          {isLoading && (
            <Card className="p-6 bg-card shadow-elegant">
              <div className="flex items-center gap-4">
                <div className="flex-shrink-0 w-8 h-8 rounded-full bg-accent text-accent-foreground flex items-center justify-center">
                  AI
                </div>
                <div className="flex items-center gap-2">
                  <Loader2 className="h-5 w-5 animate-spin text-accent" />
                  <span className="text-muted-foreground">Generating SQL query...</span>
                </div>
              </div>
            </Card>
          )}
        </div>

        {/* Input area */}
        <Card className="p-4 shadow-elegant">
          <div className="flex gap-3">
            <Textarea
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  handleSubmit();
                }
              }}
              placeholder="Ask a question about your data in plain English..."
              className="min-h-[60px] resize-none border-0 focus-visible:ring-0 focus-visible:ring-offset-0"
              disabled={isLoading}
            />
            
            <Button
              onClick={() => handleSubmit()}
              disabled={!input.trim() || isLoading}
              size="lg"
              className="flex-shrink-0 bg-gradient-to-r from-primary to-primary-glow hover:shadow-glow transition-all duration-300"
            >
              {isLoading ? (
                <Loader2 className="h-5 w-5 animate-spin" />
              ) : (
                <Send className="h-5 w-5" />
              )}
            </Button>
          </div>
        </Card>
      </div>
    </section>
  );
};

export default ChatInterface;
