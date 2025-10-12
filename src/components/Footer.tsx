import { Database } from "lucide-react";

const Footer = () => {
  return (
    <footer className="py-12 px-4 border-t bg-card">
      <div className="container mx-auto">
        <div className="flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-primary to-primary-glow flex items-center justify-center">
              <Database className="h-6 w-6 text-primary-foreground" />
            </div>
            <div>
              <div className="font-bold text-lg">SQL Generator</div>
              <div className="text-sm text-muted-foreground">Powered by AI</div>
            </div>
          </div>
          
          <div className="text-sm text-muted-foreground text-center md:text-right">
            <p>Transform natural language to SQL queries instantly</p>
            <p className="mt-1">© 2025 SQL Generator. All rights reserved.</p>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
