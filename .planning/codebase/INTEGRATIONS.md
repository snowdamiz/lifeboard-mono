# External Integrations

**Analysis Date:** 2026-03-07

## APIs & External Services

**Receipt Scanning (AI-Powered):**
- OpenRouter API - AI-powered receipt image parsing and data extraction
  - SDK/Client: `finch` (HTTP client)
  - Endpoint: `https://openrouter.ai/api/v1/chat/completions`
  - Model: bytedance-seed/seed-1.6-flash
  - Auth: `OPENROUTER_API_KEY` environment variable
  - Implementation: `server/lib/mega_planner/receipts/receipt_parser.ex`
  - Features:
    - Extracts store information (name, address, store ID, phone)
    - Parses transaction details (date, time, subtotal, tax, total)
    - Extracts line items with brand, product name, quantity, price
    - Detects MIME type and sends base64-encoded images
    - Automatic retry with exponential backoff on rate limits (429 errors)
    - Rate limit max: 3 retries with 2^retry_count * 1000ms delay
    - Timeout: 60 seconds per request

**Google OAuth 2.0:**
- Provider: Google Cloud Console OAuth
  - SDK/Client: `ueberauth` 0.10 + `ueberauth_google` 0.12
  - Callback URL: `/auth/google/callback`
  - Credentials: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`
  - Scope: email, profile
  - Configuration: `config/runtime.exs` lines 44-52
  - Routes: `server/lib/mega_planner_web/router.ex` lines 22-28

**GitHub OAuth 2.0 (Optional):**
- Provider: GitHub
  - SDK/Client: `ueberauth` 0.10 + `ueberauth_github` strategy (configured in `runtime.exs` lines 54-58)
  - Credentials: `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`
  - Configuration: Conditional in `config/runtime.exs` - only if env vars set
  - Status: Present but secondary to Google OAuth

## Data Storage

**Databases:**
- PostgreSQL 16
  - Connection: `DATABASE_URL` environment variable (production) or localhost in dev
  - Client: Ecto 3.10 with postgrex driver
  - Connection string format: `ecto://username:password@hostname:5432/database_name`
  - Dev config: `postgres://postgres@localhost/mega_planner_dev`
  - Pool size: `POOL_SIZE` env var (default 10 in production, configurable)
  - Location: `server/lib/mega_planner/repo.ex`

**File Storage:**
- Local filesystem only - No cloud storage integration detected
- File handling: Upload/download operations handled via API responses

**Caching:**
- None explicitly configured
- All data read directly from PostgreSQL

## Authentication & Identity

**Auth Provider:**
- Custom JWT-based authentication
  - Implementation: Guardian 2.3 (JWT library)
  - Token types: Access tokens (15 minutes) and Refresh tokens (30 days)
  - Configuration: `config/config.exs` lines 18-27
  - Secret key: `GUARDIAN_SECRET_KEY` environment variable
  - Issue: "mega_planner"

**OAuth Flow:**
- Request endpoint: `GET /auth/:provider` - Initiates OAuth redirect
- Callback endpoint: `GET /auth/:provider/callback` - OAuth provider redirects here
- Token refresh: `POST /auth/refresh` - Client-side token refresh (no auth required)
- Logout: `DELETE /auth/logout` - Clear session
- Implementation: `server/lib/mega_planner_web/controllers/auth_controller.ex`

**Client Auth:**
- Bearer token in Authorization header: `Authorization: Bearer {access_token}`
- Frontend token storage: localStorage (maintained in auth store)
- Auto-refresh: Client automatically refreshes tokens when 401 received
- Implementation: `client/src/services/api.ts` lines 70-118

## Monitoring & Observability

**Error Tracking:**
- None detected - No error tracking service configured

**Logs:**
- Elixir logger (console output)
- Configuration: `config/config.exs` lines 34-36
- Log level controlled via `config/dev.exs` or `config/prod.exs`
- Structured logging available via Logger module with metadata

**Telemetry:**
- Metrics collection via `telemetry_metrics` 0.6 and `telemetry_poller` 1.0
- Phoenix Live Dashboard available in development at `/dev/dashboard`
- Configuration: `config/config.exs` references telemetry integration

## CI/CD & Deployment

**Hosting:**
- Fly.io (indicated by `fly.toml` in root)
- Docker containerization via `Dockerfile`
- Health checks on PostgreSQL service

**CI Pipeline:**
- None detected - No GitHub Actions or CI config in `.github/workflows`
- Docker Compose setup for local development (`docker-compose.yml`)

**Deployment Configuration:**
- `fly.toml` - Fly.io deployment manifest
- Environment variables injected via Fly secrets at runtime
- Health check on PostgreSQL in Docker Compose

## Environment Configuration

**Required env vars:**

*Authentication:*
- `GOOGLE_CLIENT_ID` - Google OAuth client ID
- `GOOGLE_CLIENT_SECRET` - Google OAuth client secret
- `GITHUB_CLIENT_ID` - GitHub OAuth (optional)
- `GITHUB_CLIENT_SECRET` - GitHub OAuth (optional)

*Security:*
- `SECRET_KEY_BASE` - Phoenix session signing key (generate with `mix phx.gen.secret`)
- `GUARDIAN_SECRET_KEY` - JWT signing key (generate with `mix phx.gen.secret`)

*Database:*
- `DATABASE_URL` - PostgreSQL connection string (production only)
- `POOL_SIZE` - Database connection pool size (default: 10)
- `ECTO_IPV6` - Enable IPv6 for database connections (optional)

*AI/External APIs:*
- `OPENROUTER_API_KEY` - OpenRouter API key for receipt scanning

*Deployment:*
- `PHX_HOST` - Hostname for production (production only)
- `PORT` - Server port (default: 4000)
- `FRONTEND_URL` - Frontend URL for OAuth redirects (production only)

**Secrets location:**
- Local dev: `.env` file (Git ignored, copy from `env.example`)
- Production: Fly.io secrets via environment
- Configuration loader: `config/runtime.exs` handles both `.env` and environment variables

## Webhooks & Callbacks

**Incoming:**
- OAuth Callbacks:
  - `GET /auth/google/callback` - Google OAuth provider redirect
  - `GET /auth/github/callback` - GitHub OAuth provider redirect (if configured)
  - iCal Feed: `GET /api/ical/feed` - Public endpoint for calendar feed (requires token auth)

**Outgoing:**
- None detected - No outbound webhooks to external services

## API Endpoints

**Public Endpoints:**
- `GET /api/health` - Health check
- `GET /api/ical/feed` - iCal calendar feed (requires token)

**Auth Endpoints:**
- `POST /auth/refresh` - Token refresh (public)
- `GET /auth/:provider` - OAuth initiation
- `GET /auth/:provider/callback` - OAuth callback
- `DELETE /auth/logout` - Logout

**Protected API Endpoints (all prefixed with `/api/`):**
- User: `/me`, `/preferences`
- Tasks: `/tasks`, `/tasks/:id`, `/tasks/:id/steps`
- Inventory: `/inventory/sheets`, `/inventory/items`, `/inventory/trip-receipts`
- Shopping: `/shopping-lists`, `/shopping-items`
- Budget: `/budget/sources`, `/budget/entries`, `/budget/summary`
- Receipts: `/receipts/stores`, `/receipts/brands`, `/receipts/trips`, `/receipts/purchases`, `/receipts/scan`, `/receipts/confirm`
- Notes: `/notebooks`, `/pages`
- Tags: `/tags`, `/tags/search`
- Goals: `/goals`, `/goal-categories`
- Habits: `/habits`, `/habit-inventories`
- Templates: `/templates`, `/text-templates`
- Search: `/search`
- Notifications: `/notifications`
- Household: `/household`, `/invitations`
- Export: `/export/all`, `/export/tasks`, `/export/budget`, `/export/inventory`

---

*Integration audit: 2026-03-07*
