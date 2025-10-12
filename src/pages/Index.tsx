import { useRef } from "react";
import Hero from "@/components/Hero";
import ChatInterface from "@/components/ChatInterface";
import Features from "@/components/Features";
import Footer from "@/components/Footer";

const Index = () => {
  const chatRef = useRef<HTMLDivElement>(null);

  const scrollToChat = () => {
    chatRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  return (
    <div className="min-h-screen bg-background">
      <Hero onGetStarted={scrollToChat} />
      <div ref={chatRef}>
        <ChatInterface />
      </div>
      <Features />
      <Footer />
    </div>
  );
};

export default Index;
