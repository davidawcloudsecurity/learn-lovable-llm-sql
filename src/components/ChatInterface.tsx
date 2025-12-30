import { useState, useEffect, useRef } from 'react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Card } from '@/components/ui/card';
import { Send, Square } from 'lucide-react';
import { Badge } from '@/components/ui/badge';

interface Message {
  id: string;
  type: 'user' | 'assistant';
  text: string;
}

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api';

const ChatGPTInterface = () => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [thinkingSeconds, setThinkingSeconds] = useState(0);
  const abortControllerRef = useRef<AbortController | null>(null);

  // Timer effect
  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (isLoading) {
      setThinkingSeconds(0);
      interval = setInterval(() => {
        setThinkingSeconds(prev => prev + 1);
      }, 1000);
    }
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [isLoading]);

  const handleStop = () => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
      abortControllerRef.current = null;
      setIsLoading(false);
    }
  };

  const handleSubmit = async () => {
    const prompt = input.trim();
    if (!prompt || isLoading) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      type: 'user',
      text: prompt,
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    abortControllerRef.current = new AbortController();

    try {
      const response = await fetch(`${API_BASE_URL}/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt }),
        signal: abortControllerRef.current.signal,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const reader = response.body?.getReader();
      if (!reader) {
        throw new Error('No response body');
      }

      const decoder = new TextDecoder();
      let assistantText = '';

      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        type: 'assistant',
        text: '',
      };

      setMessages(prev => [...prev, assistantMessage]);

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value, { stream: true });
        assistantText += chunk;

        setMessages(prev => prev.map(msg =>
          msg.id === assistantMessage.id
            ? { ...msg, text: assistantText }
            : msg
        ));
      }
    } catch (error) {
      if ((error as Error).name === 'AbortError') {
        // Request was cancelled
      } else {
        console.error('Streaming error:', error);
        // Add error message to chat
        const errorMessage: Message = {
          id: (Date.now() + 2).toString(),
          type: 'assistant',
          text: 'Sorry, there was an error processing your request.',
        };
        setMessages(prev => [...prev, errorMessage]);
      }
    } finally {
      setIsLoading(false);
      abortControllerRef.current = null;
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  return (
    <div className="flex flex-col h-screen bg-background">
      {/* Messages area */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 && (
          <div className="text-center text-muted-foreground mt-12">
            <h2 className="text-2xl font-semibold mb-2">ChatGPT-like Interface</h2>
            <p>Start a conversation by typing a message below.</p>
          </div>
        )}

        {messages.map(message => (
          <Card key={message.id} className="p-4 max-w-4xl mx-auto">
            <div className="flex items-start gap-3">
              <div className={`flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium ${
                message.type === 'user'
                  ? 'bg-primary text-primary-foreground'
                  : 'bg-muted text-muted-foreground'
              }`}>
                {message.type === 'user' ? 'U' : 'AI'}
              </div>
              <div className="flex-1">
                <div className="font-medium mb-1">
                  {message.type === 'user' ? 'You' : 'Assistant'}
                </div>
                <div className="text-sm leading-relaxed whitespace-pre-wrap">
                  {message.text || (isLoading && message.type === 'assistant' ? '...' : '')}
                </div>
              </div>
            </div>
          </Card>
        ))}

        {isLoading && (
          <Card className="p-4 max-w-4xl mx-auto">
            <div className="flex items-start gap-3">
              <div className="flex-shrink-0 w-8 h-8 rounded-full bg-muted text-muted-foreground flex items-center justify-center text-sm font-medium">
                AI
              </div>
              <div className="flex-1">
                <div className="font-medium mb-1">Assistant</div>
                <div className="text-sm leading-relaxed">
                  {messages[messages.length - 1]?.text || '...'}
                </div>
              </div>
            </div>
          </Card>
        )}
      </div>

      {/* Input area */}
      <div className="border-t bg-background p-4">
        <div className="max-w-4xl mx-auto">
          {/* Reasoning indicator */}
          {isLoading && (
            <div className="mb-3 flex items-center gap-2">
              <Badge variant="secondary" className="text-xs">
                Reasoning
              </Badge>
              <span className="text-sm text-muted-foreground">
                Thinking for {thinkingSeconds}s
              </span>
            </div>
          )}

          <div className="flex gap-3">
            <Textarea
              value={input}
              onChange={e => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Your prompt here..."
              className="min-h-[60px] resize-none flex-1"
              disabled={isLoading}
            />

            {isLoading ? (
              <Button
                onClick={handleStop}
                size="lg"
                variant="destructive"
                className="flex-shrink-0"
              >
                <Square className="h-4 w-4" />
              </Button>
            ) : (
              <Button
                onClick={handleSubmit}
                disabled={!input.trim()}
                size="lg"
                className="flex-shrink-0"
              >
                <Send className="h-4 w-4" />
              </Button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default ChatGPTInterface;
