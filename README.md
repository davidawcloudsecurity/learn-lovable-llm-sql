# Natural Language to SQL Platform

AI-powered platform that transforms natural language questions into SQL queries instantly. Built with React, TypeScript, and Tailwind CSS.

## Project info

**URL**: https://lovable.dev/projects/911f48af-532a-45c5-b9a8-f59c4b335498

## How can I edit this code?

There are several ways of editing your application.

**Use Lovable**

Simply visit the [Lovable Project](https://lovable.dev/projects/911f48af-532a-45c5-b9a8-f59c4b335498) and start prompting.

Changes made via Lovable will be committed automatically to this repo.

**Use your preferred IDE**

If you want to work locally using your own IDE, you can clone this repo and push changes. Pushed changes will also be reflected in Lovable.

The only requirement is having Node.js & npm installed - [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating)

Follow these steps:

```sh
# Step 1: Clone the repository using the project's Git URL.
git clone <YOUR_GIT_URL>

# Step 2: Navigate to the project directory.
cd <YOUR_PROJECT_NAME>

# Step 3: Install the necessary dependencies.
npm i

# Step 4: Start the development server with auto-reloading and an instant preview.
npm run dev
```

**Edit a file directly in GitHub**

- Navigate to the desired file(s).
- Click the "Edit" button (pencil icon) at the top right of the file view.
- Make your changes and commit the changes.

**Use GitHub Codespaces**

- Navigate to the main page of your repository.
- Click on the "Code" button (green button) near the top right.
- Select the "Codespaces" tab.
- Click on "New codespace" to launch a new Codespace environment.
- Edit files directly within the Codespace and commit and push your changes once you're done.

## What Has Been Created

### ✅ Frontend Components
- **Hero Section** (`src/components/Hero.tsx`) - Landing page with gradient design, call-to-action buttons, and animated elements
- **Chat Interface** (`src/components/ChatInterface.tsx`) - Interactive chat with example queries, message history, and SQL code display with copy functionality
- **Features Section** (`src/components/Features.tsx`) - Showcase of 6 key platform benefits (Lightning Fast, Enterprise Ready, Smart AI, etc.)
- **Footer** (`src/components/Footer.tsx`) - Branding and copyright information

### 🎨 Design System
- **Color Palette** - Deep navy primary (#1a365d) with vibrant orange accents (#ff6b35)
- **Design Tokens** - Semantic HSL color variables in `src/index.css`
- **Animations** - Gradient effects, hover states, pulse animations, floating elements
- **Custom Shadows** - `shadow-elegant` and `shadow-glow` for depth
- **Typography** - Responsive text sizing with gradient text effects

### 🛠️ Current Functionality
- Responsive layout for mobile, tablet, and desktop
- Simulated AI responses (placeholder for actual AI integration)
- Copy-to-clipboard for generated SQL queries
- Smooth scroll navigation
- Example queries for user guidance
- Toast notifications for user feedback

## What Is Missing

### 🚀 Critical Features (Backend Required)
1. **Real AI Integration** - Connect to Lovable AI for actual NL-to-SQL generation
   - Need to enable Lovable Cloud
   - Create edge function to call AI gateway
   - Implement streaming responses for real-time query generation

2. **Database Schema Management**
   - Allow users to upload/paste their database schema
   - Store schemas in database
   - Pass schema as context to AI for accurate SQL generation

3. **Query Execution & Results**
   - Connect to user's database (with credentials)
   - Execute generated SQL queries
   - Display results in formatted tables
   - Handle query errors gracefully

4. **User Authentication**
   - Email/password login with Lovable Cloud
   - User session management
   - Protect chat history and schemas per user

5. **Query History & Persistence**
   - Save all conversations to database
   - Allow users to browse past queries
   - Export conversation history

### 📈 Enhancement Features
6. **Schema Validation** - Validate uploaded schemas before processing
7. **Query Optimization** - Suggest query improvements
8. **Multi-Database Support** - Support PostgreSQL, MySQL, SQL Server, etc.
9. **Export Options** - Download results as CSV, JSON, Excel
10. **Query Templates** - Pre-built templates for common queries
11. **Collaboration** - Share queries with team members
12. **API Access** - REST API for programmatic access

## Technologies

This project is built with:

- **Vite** - Fast build tool and dev server
- **TypeScript** - Type-safe JavaScript
- **React** - UI component library
- **shadcn-ui** - Accessible component system
- **Tailwind CSS** - Utility-first CSS framework
- **Lucide React** - Icon library

## How can I deploy this project?

Simply open [Lovable](https://lovable.dev/projects/911f48af-532a-45c5-b9a8-f59c4b335498) and click on Share -> Publish.

## Can I connect a custom domain to my Lovable project?

Yes, you can!

To connect a domain, navigate to Project > Settings > Domains and click Connect Domain.

Read more here: [Setting up a custom domain](https://docs.lovable.dev/features/custom-domain#custom-domain)
