# Technology Stack

**Analysis Date:** 2026-03-07

## Languages

**Primary:**
- Elixir 1.15 - Backend business logic, API server, database layer
- TypeScript 5.3.3 - Frontend UI logic, type-safe development
- Vue 3.4.15 - Frontend reactive components and templates
- JavaScript (ES modules) - Frontend utility scripts

**Secondary:**
- SQL - Database schema and queries via Ecto
- HTML/CSS - Template rendering and styling

## Runtime

**Environment:**
- Elixir/Erlang - Backend runtime (Phoenix framework)
- Node.js (not explicitly versioned) - Frontend build tooling only

**Package Manager:**
- Mix - Elixir package manager (`mix.exs`)
- npm - JavaScript package manager (`package.json` and `client/package.json`)
- Lockfiles: `mix.lock` and `package-lock.json`

## Frameworks

**Core:**
- Phoenix 1.7.10 - Web framework, REST API, request routing
- Ecto 3.10 - ORM and database query builder
- Vue 3.4.15 - Frontend view library and reactive state
- Pinia 2.1.7 - State management for Vue stores

**Testing:**
- Playwright 1.58.1 - End-to-end testing framework (client)
- ExUnit - Elixir's built-in test framework (server)

**Build/Dev:**
- Vite 5.0.12 - Frontend build tool and dev server
- esbuild 0.25.0 - JavaScript bundler
- TypeScript compiler - Type checking via `vue-tsc`
- ESLint 8.56.0 - JavaScript/Vue linting

## Key Dependencies

**Critical:**
- `phoenix_ecto` 4.4 - Phoenix/Ecto integration for database operations
- `postgrex` - PostgreSQL driver for Elixir
- `jason` 1.2 - JSON encoding/decoding
- `guardian` 2.3 - JWT token authentication
- `ueberauth` 0.10 & `ueberauth_google` 0.12 - OAuth 2.0 authentication with Google

**Frontend UI:**
- `radix-vue` 1.4.9 - Headless component library
- `lucide-vue-next` 0.312.0 - Icon library
- `tailwindcss` 3.4.1 - CSS framework
- `chart.js` 4.5.1 + `vue-chartjs` 5.3.3 - Charting library
- `grid-layout-plus` 1.0.5 - Draggable grid layouts
- `marked` 11.1.1 - Markdown parsing
- `class-variance-authority` 0.7.0 - CSS class composition
- `date-fns` 3.3.1 - Date manipulation

**Frontend Utilities:**
- `@vueuse/core` 10.7.2 - Vue composition utilities
- `vue-router` 4.2.5 - Client-side routing
- `clsx` 2.1.0 - Conditional class names
- `tailwind-merge` 2.2.1 - Merge Tailwind CSS classes

**Backend Infrastructure:**
- `finch` 0.13 - HTTP client for external API calls (used for OpenRouter)
- `swoosh` 1.3 - Email sending library with multiple adapters
- `telemetry_metrics` 0.6 - Application metrics collection
- `telemetry_poller` 1.0 - Metrics collection polling
- `plug_cowboy` 2.5 - HTTP server adapter
- `cors_plug` 3.0 - CORS support
- `timex` 3.7 - Date/time library
- `decimal` 2.0 - Precise decimal arithmetic
- `dotenvy` 0.8.0 - Environment variable loading

**Development:**
- `@rushstack/eslint-patch` 1.7.2 - ESLint Node patch
- `@tsconfig/node20` 20.1.2 - TypeScript config for Node 20
- `@types/node` 20.19.31 - Node.js TypeScript types
- `autoprefixer` 10.4.17 - CSS vendor prefixing
- `postcss` 8.4.34 - CSS transformation

## Configuration

**Environment:**
- `.env` file for local development (Git ignored, created from `env.example`)
- Environment variables in `/Users/sn0w/Documents/dev/lifeboard-mono/server/env.example`
- Runtime configuration via `config/` directory:
  - `config/config.exs` - Shared configuration
  - `config/dev.exs` - Development settings
  - `config/prod.exs` - Production settings
  - `config/runtime.exs` - Runtime environment variable handling

**Frontend Build:**
- `vite.config.ts` - Vite configuration with API proxy
- `tsconfig.json` - TypeScript compiler options
- `tsconfig.app.json` - Application-specific TypeScript config
- `vite.config.ts.timestamp-*` - Build timestamps
- `tailwind.config.js` - Tailwind CSS configuration
- `postcss.config.js` - PostCSS pipeline
- `playwright.config.ts` - E2E test configuration

**Backend:**
- `.formatter.exs` - Elixir code formatter configuration
- `fly.toml` - Fly.io deployment configuration
- `Dockerfile` - Docker image for containerization
- `.dockerignore` - Files excluded from Docker builds

## Platform Requirements

**Development:**
- Elixir 1.15
- Erlang/OTP compatible with Elixir 1.15
- PostgreSQL 16 (via Docker via `docker-compose.yml`)
- Node.js (for npm and frontend build tools)
- Git

**Production:**
- Deployment target: Fly.io (indicated by `fly.toml` and production Docker setup)
- PostgreSQL 16 database
- Environment variables: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `OPENROUTER_API_KEY`, `SECRET_KEY_BASE`, `GUARDIAN_SECRET_KEY`, `DATABASE_URL`, `POOL_SIZE`, `PHX_HOST`, `PORT`, `FRONTEND_URL`
- Docker containerization for server deployment

---

*Stack analysis: 2026-03-07*
