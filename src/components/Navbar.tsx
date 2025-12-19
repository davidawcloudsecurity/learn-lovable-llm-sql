import React, { useState } from "react";
import { Button } from "@/components/ui/button";
import { ArrowRight, Menu, X } from "lucide-react";

interface NavbarProps {
  onGetStarted: () => void;
}

const Navbar: React.FC<NavbarProps> = ({ onGetStarted }) => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const toggleMenu = () => setIsMenuOpen(!isMenuOpen);
  const closeMenu = () => setIsMenuOpen(false);

  const handleLinkClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
    e.preventDefault();
    closeMenu();
    // Add navigation logic here if needed
  };
  return (
    <nav aria-label="Main navigation" className="fixed top-0 left-0 right-0 z-50 bg-background/80 backdrop-blur-md border-b border-border/50">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <div className="flex items-center">
            <span className="text-xl font-bold bg-gradient-to-r from-primary to-primary-glow bg-clip-text text-transparent">
              Text2SQL
            </span>
          </div>

          {/* Right Side: Mobile Menu, Desktop Nav Links, CTA Button */}
          <div className="flex items-center gap-4">
            {/* Mobile Menu Button */}
            <Button
              variant="ghost"
              size="icon"
              onClick={toggleMenu}
              aria-expanded={isMenuOpen}
              aria-controls="mobile-menu"
              className="md:hidden"
            >
              {isMenuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
            </Button>

            {/* Navigation Links - Desktop */}
            <div className="hidden md:flex items-center gap-6">
              <a
                href="#"
                onClick={handleLinkClick}
                className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded"
              >
                Get App
              </a>
              <a
                href="#"
                onClick={handleLinkClick}
                className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded"
              >
                Sign Up
              </a>
              <a
                href="#"
                onClick={handleLinkClick}
                className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded"
              >
                Log In
              </a>
            </div>

            {/* CTA Button */}
            <Button
              onClick={onGetStarted}
              className="group bg-gradient-to-r from-primary to-primary-glow hover:shadow-glow transition-all duration-300 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2"
            >
              Get Started
              <ArrowRight className="ml-2 h-4 w-4 group-hover:translate-x-1 transition-transform" />
            </Button>
          </div>
        </div>
      </div>

      {/* Mobile Menu */}
      <div
        id="mobile-menu"
        className={`md:hidden bg-background/95 backdrop-blur-md border-b border-border/50 transition-all duration-300 ${
          isMenuOpen ? 'max-h-96 opacity-100' : 'max-h-0 opacity-0 overflow-hidden'
        }`}
      >
        <div className="container mx-auto px-4 py-4">
          <div className="flex flex-col gap-4">
            <a
              href="#"
              onClick={handleLinkClick}
              className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors py-2 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded"
            >
              Get App
            </a>
            <a
              href="#"
              onClick={handleLinkClick}
              className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors py-2 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded"
            >
              Sign Up
            </a>
            <a
              href="#"
              onClick={handleLinkClick}
              className="text-sm font-medium text-muted-foreground hover:text-foreground transition-colors py-2 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded"
            >
              Log In
            </a>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
