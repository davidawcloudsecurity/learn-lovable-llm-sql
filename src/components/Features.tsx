import { Card } from "@/components/ui/card";
import { Zap, Shield, Code2, Users, TrendingUp, Lock } from "lucide-react";

const features = [
  {
    icon: Zap,
    title: "Lightning Fast",
    description: "Generate complex SQL queries in seconds, not hours. Boost your team's productivity instantly.",
  },
  {
    icon: Shield,
    title: "Enterprise Ready",
    description: "Built with security and scalability in mind. Ready for production environments from day one.",
  },
  {
    icon: Code2,
    title: "Smart AI Engine",
    description: "Powered by advanced language models that understand context and generate optimized queries.",
  },
  {
    icon: Users,
    title: "Democratize Data",
    description: "Enable non-technical team members to query databases without learning SQL syntax.",
  },
  {
    icon: TrendingUp,
    title: "Continuous Learning",
    description: "The AI improves with each query, learning your database schema and business logic.",
  },
  {
    icon: Lock,
    title: "Secure by Default",
    description: "All queries are validated and sanitized. Your data security is our top priority.",
  },
];

const Features = () => {
  return (
    <section className="py-20 px-4 bg-secondary/30">
      <div className="container mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl lg:text-5xl font-bold mb-4">
            Why Choose Our Platform
          </h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Everything you need to transform natural language into powerful SQL queries
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          {features.map((feature, idx) => {
            const Icon = feature.icon;
            return (
              <Card
                key={idx}
                className="p-8 hover:shadow-elegant transition-all duration-300 hover:-translate-y-1 border-2 hover:border-primary/20 bg-card group"
              >
                <div className="mb-4 relative">
                  <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-primary to-primary-glow flex items-center justify-center group-hover:shadow-glow transition-shadow duration-300">
                    <Icon className="h-7 w-7 text-primary-foreground" />
                  </div>
                  <div className="absolute top-0 left-0 w-14 h-14 rounded-xl bg-accent/20 blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-300"></div>
                </div>
                
                <h3 className="text-xl font-bold mb-3 group-hover:text-primary transition-colors">
                  {feature.title}
                </h3>
                
                <p className="text-muted-foreground leading-relaxed">
                  {feature.description}
                </p>
              </Card>
            );
          })}
        </div>
      </div>
    </section>
  );
};

export default Features;
