---
description: Set up the development environment from scratch
---

This workflow guides an AI agent (or human) to get the application up and running locally.

1.  **Check Prerequisites**
    Ensure the following are installed and running:
    *   Docker Desktop (PostgreSQL container)
    *   Node.js 18+
    *   Elixir 1.15+ (with Erlang 26+)

2.  **Start Database**
    // turbo
    Run `docker-compose up -d` in the project root.
    *(Wait a few seconds for the database to be ready)*

3.  **Configure Environment**
    Check if `server/.env` exists. If not:
    *   Copy `server/env.example` to `server/.env`.
    *   (Optional) The default example values are sufficient for the server to start in basic dev mode.
    *   To enable Google/GitHub Auth, you would need to populate the client IDs in `server/.env`.
    *   To generate secure keys for `SECRET_KEY_BASE` (if you plan to run in production mode locally), run `mix phx.gen.secret` in the `server` directory and update the `.env` file.

4.  **Install Dependencies & Setup**
    // turbo
    Run `npm run setup` in the project root.
    *   This runs `npm install` (for both root and client), `mix deps.get`, and `mix setup` (which handles database creation and migration).

5.  **Verify & Run**
    // turbo
    Run `npm run dev` in the project root.
    *   This concurrently starts:
        *   Backend: via `cd server && mix phx.server` -> available at http://localhost:4000
        *   Frontend: via `vite` -> available at http://localhost:5173

6.  **Troubleshooting**
    *   If `mix setup` fails with database errors, ensure Docker is running and the port 5432 is free.
    *   If frontend fails to connect to backend, ensure backend is running on port 4000.
