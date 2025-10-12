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

const ChatInterface = () => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const { toast } = useToast();

  const exampleQueries = [
    "Show me all customers who made purchases in the last 30 days",
    "Find the top 10 products by revenue this month",
    "List employees with salary above average in the sales department",
  ];

  const handleSubmit = async (queryText?: string) => {
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

    // Simulate AI processing (replace with actual API call)
    setTimeout(() => {
      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        type: "assistant",
        text: "I've converted your question into an SQL query:",
        sql: `SELECT customer_id, customer_name, purchase_date, total_amount
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.purchase_date >= DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY)
ORDER BY o.purchase_date DESC;`,
      };
      setMessages((prev) => [...prev, assistantMessage]);
      setIsLoading(false);
      
      toast({
        title: "Query Generated",
        description: "Your SQL query is ready to use",
      });
    }, 2000);
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
            <p className="text-sm font-medium text-muted-foreground mb-3">Try these examples:</p>
            {exampleQueries.map((query, idx) => (
              <button
                key={idx}
                onClick={() => handleSubmit(query)}
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
                      <pre className="bg-muted p-4 rounded-lg overflow-x-auto text-sm font-mono">
                        <code>{message.sql}</code>
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
