import { useRef } from "react";
import Navbar from "@/components/Navbar";
import Hero from "@/components/Hero";
import ChatInterface from "@/components/ChatInterface";
import Features from "@/components/Features";
import Footer from "@/components/Footer";

const Index = () => {
  const chatRef = useRef<HTMLDivElement>(null);
  const featuresRef = useRef<HTMLDivElement>(null);

  const scrollToChat = () => {
    chatRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  const scrollToFeatures = () => {
    featuresRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  return (
    <div className="min-h-screen bg-background">
      <Navbar onGetStarted={scrollToChat} />
      <Hero onGetStarted={scrollToChat} onViewExamples={scrollToFeatures} />
      <div ref={chatRef}>
        <ChatInterface />
      </div>
      <div ref={featuresRef} id="examples" className="scroll-mt-24">
        <Features />
      </div>
      <Footer />
    </div>
  );
};

export default Index;
