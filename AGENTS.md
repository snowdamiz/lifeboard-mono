# AGENTS.md - AI Coding Assistant Guide for LifeBoard

> A personal planning application with Calendar, Inventory, Budget, Notes, Goals, and Habits modules.

## Quick Reference

| Component | Technology | Location |
|-----------|------------|----------|
| Frontend | Vue 3 + TypeScript + Tailwind | `client/` |
| Backend | Elixir/Phoenix REST API | `server/` |
| Database | PostgreSQL 16 | Docker container |
| Auth | OAuth 2.0 (Google, GitHub) + JWT | Via Guardian |
| Deploy | Fly.io (auto-deploy on push to `master`) | `.github/workflows/deploy.yml` |

---

## Development Environment

### Prerequisites

- **Docker Desktop** – PostgreSQL runs in a container
- **Node.js 18+** – Frontend tooling
- **Elixir 1.15+** (with Erlang 26+) – Backend runtime

### Start Development

```bash
# 1. Start the database
docker-compose up -d

# 2. Install all dependencies and set up database
npm run setup

# 3. Run both frontend and backend
npm run dev
```

- **Frontend**: http://localhost:5173
- **Backend API**: http://localhost:4000
- **Live Dashboard** (dev only): http://localhost:4000/dev/dashboard

### Verify Build Before Commit

```bash
# Frontend type-check + build (catches TypeScript errors)
cd client && npm run build

# Backend tests
cd server && mix test
```

---

## Project Structure

```
lifeboard-mono/
├── client/                    # Vue 3 SPA
│   ├── src/
│   │   ├── components/        # Reusable UI (ui/ for primitives, shared/ for complex)
│   │   ├── views/             # Page-level components
│   │   ├── stores/            # Pinia stores (one per domain)
│   │   ├── services/api.ts    # API client singleton
│   │   ├── types/index.ts     # ALL TypeScript interfaces
│   │   └── lib/utils.ts       # cn() utility for Tailwind classes
│   └── tailwind.config.js     # Theme configuration
│
├── server/                    # Phoenix REST API
│   ├── lib/
│   │   ├── mega_planner/      # Business logic contexts
│   │   └── mega_planner_web/  # Controllers, router, plugs
│   ├── priv/repo/migrations/  # Database migrations
│   └── config/                # Environment configs
│
├── .agent/workflows/          # AI agent workflows (see /setup_dev_env)
├── .antigravity/              # Agent skills and knowledge
└── docker-compose.yml         # Local PostgreSQL
```

---

## Coding Conventions

### Vue/TypeScript (Frontend)

1. **Always use Composition API with `<script setup lang="ts">`**
2. **Define props with TypeScript interfaces**:
   ```vue
   <script setup lang="ts">
   import type { Habit } from '@/types'
   
   interface Props {
     habit: Habit
     editable?: boolean
   }
   const props = withDefaults(defineProps<Props>(), {
     editable: false
   })
   </script>
   ```
3. **Use the `cn()` utility** for conditional Tailwind classes:
   ```ts
   import { cn } from '@/lib/utils'
   const classes = cn('base-class', isActive && 'active-class')
   ```
4. **Import types from `@/types`** – never create duplicate interfaces
5. **Use Pinia stores with setup function syntax**:
   ```ts
   export const useHabitsStore = defineStore('habits', () => {
     const habits = ref<Habit[]>([])
     const loading = ref(false)
     // ...
     return { habits, loading, fetchHabits }
   })
   ```
6. **Use the `api` singleton** for all HTTP requests (`@/services/api`)

### Elixir/Phoenix (Backend)

1. **Context module pattern** – Business logic in `lib/mega_planner/`, not controllers
2. **Always scope by `household_id`**:
   ```elixir
   def list_habits(household_id, opts \\ []) do
     from(h in Habit, where: h.household_id == ^household_id)
     |> Repo.all()
   end
   ```
3. **Use module attributes for preloads**:
   ```elixir
   @habit_preloads [:tags, :completions]
   ```
4. **Wrap all responses in `{ "data": ... }`**
5. **Controllers use `action_fallback MegaPlannerWeb.FallbackController`**

### API Response Format

All endpoints return JSON in this format:
```json
{
  "data": { ... }  // Single object or array
}
```

Errors return:
```json
{
  "error": "Description"  // or "errors": { "field": ["message"] }
}
```

---

## Key Domain Concepts

### Multi-Tenancy via Households

Every data entity belongs to a `household_id`. Users authenticate via OAuth and belong to exactly one household. **Never bypass household scoping** – this is a security boundary.

### Core Entities

| Entity | Notes |
|--------|-------|
| **Tasks** | Calendar items with steps, tags, recurrence |
| **Habits** | Daily/weekly tracking with completions, streaks |
| **HabitInventories** | Groups of habits (whole-day or partial-day coverage) |
| **Goals** | Long-term objectives with milestones |
| **InventorySheets** | Collections of items (e.g., Pantry, Freezer) |
| **ShoppingLists** | Auto-generated from low inventory |
| **Trips/Stops/Purchases** | Shopping trip logistics |
| **Notebooks/Pages** | Markdown notes with linking |
| **Tags** | Cross-cutting categorization |

---

## Common Tasks

### Add a New API Endpoint

1. **Define route** in `server/lib/mega_planner_web/router.ex`
2. **Create/update controller** in `server/lib/mega_planner_web/controllers/`
3. **Add context function** in `server/lib/mega_planner/` (keep controllers thin)
4. **Add API method** in `client/src/services/api.ts`
5. **Add TypeScript types** in `client/src/types/index.ts` if new shapes

### Add a New Vue Component

1. Place in `client/src/components/ui/` (primitives) or `client/src/components/shared/` (complex)
2. Use `<script setup lang="ts">` with typed props
3. Use existing UI primitives from `components/ui/` (Button, Select, etc.)
4. Check `@/types` for existing interfaces

### Create a Database Migration

```bash
cd server
mix ecto.gen.migration add_some_field
# Edit the migration file in priv/repo/migrations/
mix ecto.migrate
```

---

## Testing

### Backend

```bash
cd server
mix test                      # Run all tests
mix test test/path/to_test.exs  # Run specific file
mix test --failed             # Rerun failed tests
```

### Frontend

```bash
cd client
npm run build    # Type-check via vue-tsc + production build
npm run lint     # ESLint + fix
```

> **Note**: There is no Jest/Vitest test suite currently. Type-checking via `vue-tsc` during build is the primary frontend validation.

---

## Git & Deployment

### Workflow

1. Commit changes: `git add -A && git commit -m "Descriptive message"`
2. Pull with rebase: `git pull --rebase origin master`
3. Resolve conflicts if any (watch for `null` vs `undefined` swaps in Vue)
4. **Run `npm run build`** in client to catch TypeScript errors before pushing
5. Push: `git push origin master`

### Auto-Deploy

Pushing to `master` triggers GitHub Actions (`.github/workflows/deploy.yml`) which deploys both client and server to Fly.io.

### Common Hazards

- **Orphan Erlang processes**: If API calls are ignored, check `netstat -ano | findstr ":4000"` and kill stale `beam.smp` processes
- **Conflict resolution in Vue**: Merging often swaps `null` for `undefined` – always verify with `npm run build`
- **Stale conflict markers**: Grep for `<<<<<<<` after rebasing

---

## Do's

- ✅ Follow existing patterns in the codebase
- ✅ Use types from `client/src/types/index.ts`
- ✅ Scope all backend queries by `household_id`
- ✅ Use the `api` singleton for HTTP requests
- ✅ Use `cn()` for conditional Tailwind classes
- ✅ Keep business logic in Phoenix contexts
- ✅ Run `npm run build` before pushing changes
- ✅ Use module attributes for Ecto preloads
- ✅ Use `@click.stop` on nested interactive elements in Vue

## Don'ts

- ❌ Add dependencies without clear justification
- ❌ Put business logic in controllers
- ❌ Hardcode environment values (use config)
- ❌ Bypass household scoping (security risk)
- ❌ Use `any` type without justification
- ❌ Create new UI components if existing ones suffice
- ❌ Commit without running type-check on frontend

---

## Environment Variables

### Backend (`server/.env`)

Copy from `server/env.example` and configure:

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection (auto-set in Docker) |
| `SECRET_KEY_BASE` | Phoenix secret (generate with `mix phx.gen.secret`) |
| `GUARDIAN_SECRET_KEY` | JWT signing key |
| `GOOGLE_CLIENT_ID/SECRET` | OAuth credentials |
| `GITHUB_CLIENT_ID/SECRET` | OAuth credentials |

### Frontend

| Variable | Purpose |
|----------|---------|
| `VITE_API_URL` | Backend URL (defaults to same origin in production) |

---

## Troubleshooting

### Port 4000 Already in Use

```powershell
# Find and kill orphan Erlang processes (Windows)
Get-Process -Name "beam.smp","erl" -ErrorAction SilentlyContinue | Stop-Process -Force
```

### Database Connection Failed

1. Ensure Docker is running: `docker-compose up -d`
2. Wait a few seconds for PostgreSQL to initialize
3. Check container: `docker ps`

### Frontend Build Fails After Merge

Common cause: `null` vs `undefined` mismatch from conflict resolution.
Solution: Check template initializations in `.vue` files.

### API Returning 401 on Fresh Start

The browser may have stale tokens. Clear localStorage or use incognito mode.

---

## Agent-Specific Notes

### Knowledge Base

The `.antigravity/` directory contains skills and the `knowledge/` directory contains distilled Knowledge Items (KIs) on topics like:
- Custom UI component patterns
- Elixir debugging techniques
- Layout stabilization patterns
- Acquisition/inventory management flows

**Check relevant KIs before implementing patterns that may already be documented.**

### Workflows

The `.agent/workflows/` directory contains step-by-step guides. Use `/setup_dev_env` to set up the development environment.

### File-Scoped Validation

For quick validation of a single Vue file's types:
```bash
cd client
npx vue-tsc --noEmit src/views/SomeView.vue
```

---

## Legacy: LifeBoard-Simple

The `LifeBoard-Simple/` directory contains a standalone Java/JavaScript version (pure HTTP server, SQLite, vanilla JS). **Do not modify** unless specifically requested – it is not integrated with the main stack.
