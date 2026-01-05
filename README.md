# MegaPlanner

A personal planning web application with Calendar, Inventory, Budget Calendar, and Scratch Pad modules.

## Tech Stack

- **Frontend**: Vue 3 + Vite + TypeScript + Tailwind CSS + shadcn-vue
- **Backend**: Phoenix Framework (Elixir)
- **Database**: PostgreSQL 16
- **Authentication**: OAuth 2.0 (Google, GitHub)

## Prerequisites

- [Docker](https://www.docker.com/) and Docker Compose
- [Elixir](https://elixir-lang.org/install.html) 1.15+ and Erlang 26+
- [Node.js](https://nodejs.org/) 18+ and npm

## Development Setup

### 1. Start PostgreSQL

```bash
docker-compose up -d
```

### 2. Backend Setup

```bash
cd server
mix deps.get
mix ecto.setup
mix phx.server
```

> **Note:** The `.env` file is automatically loaded in development mode via the `dotenvy` package.

The API will be available at `http://localhost:4000`

### 3. Frontend Setup

In a separate terminal:

```bash
cd client
npm install
npm run dev
```

The frontend will be available at `http://localhost:5173`

## OAuth Configuration

1. Copy the example environment file:
   ```bash
   cd server
   cp env.example .env
   ```

2. Generate secret keys:
   ```bash
   mix phx.gen.secret  # Run twice, use for SECRET_KEY_BASE and GUARDIAN_SECRET_KEY
   ```

3. Configure OAuth credentials in `.env`:

### Getting Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Navigate to "APIs & Services" > "Credentials"
4. Click "Create Credentials" > "OAuth client ID"
5. Select "Web application"
6. Add authorized redirect URI: `http://localhost:4000/auth/google/callback`
7. Copy Client ID and Client Secret to your `.env` file

### Getting GitHub OAuth Credentials

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click "New OAuth App"
3. Set Homepage URL: `http://localhost:5173`
4. Set Authorization callback URL: `http://localhost:4000/auth/github/callback`
5. Copy Client ID and generate a Client Secret for your `.env` file

## Project Structure

```
mega-planner/
├── client/                    # Vue frontend
│   ├── src/
│   │   ├── components/        # Reusable UI components
│   │   ├── views/             # Page components
│   │   ├── stores/            # Pinia stores
│   │   ├── composables/       # Vue composables
│   │   ├── services/          # API client services
│   │   ├── types/             # TypeScript types
│   │   └── lib/               # Utilities
│   └── ...
├── server/                    # Phoenix backend
│   ├── lib/
│   │   ├── mega_planner/      # Business logic (contexts)
│   │   └── mega_planner_web/  # Web layer
│   └── ...
├── docker-compose.yml
└── README.md
```

## Features (MVP)

- **Calendar**: Daily/weekly views, time-based tasks, to-do lists with priorities
- **Inventory**: Item tracking with quantities, necessity flags, shopping lists
- **Budget**: Income/expense sources, monthly summaries, calendar view
- **Scratch Pad**: Notebooks, pages, linking to other items
- **Global Search**: Search across all modules

