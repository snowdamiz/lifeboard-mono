# AGENTS.md - AI Assistant Guide for MegaPlanner

## Project Overview

MegaPlanner is a personal planning web application with modules for Calendar, Inventory, Budget, Notes, Goals, and Habits. It features multi-tenant support via households and OAuth authentication.

### Monorepo Structure

```
mega-planner/
├── client/              # Vue 3 + TypeScript SPA
├── server/              # Elixir/Phoenix REST API
├── LifeBoard-Simple/    # Standalone Java/JS alternative (not actively developed)
└── docker-compose.yml   # PostgreSQL for development
```

## Architecture

- **Frontend**: Single-page application communicating via REST API
- **Backend**: Phoenix JSON API with PostgreSQL database
- **Auth**: OAuth 2.0 (Google, GitHub) with JWT access/refresh tokens
- **Multi-tenancy**: Users belong to households; all data is scoped by `household_id`

## Tech Stack

### Frontend (`client/`)

| Technology | Purpose |
|------------|---------|
| Vue 3 | UI framework (Composition API with `<script setup>`) |
| TypeScript | Type safety |
| Pinia | State management |
| Tailwind CSS | Styling with CSS variables for theming |
| Radix Vue | Accessible UI primitives |
| Vite | Build tool |

### Backend (`server/`)

| Technology | Purpose |
|------------|---------|
| Elixir 1.15+ | Language |
| Phoenix 1.7 | Web framework (JSON API only) |
| Ecto | Database ORM |
| PostgreSQL 16 | Database (binary UUIDs) |
| Guardian | JWT authentication |

## Development Setup

```bash
# 1. Start PostgreSQL
docker-compose up -d

# 2. Backend (terminal 1)
cd server
mix deps.get
mix ecto.setup
mix phx.server
# API runs at http://localhost:4000

# 3. Frontend (terminal 2)
cd client
npm install
npm run dev
# UI runs at http://localhost:5173
```

## Key Files Reference

### Frontend

| Path | Purpose |
|------|---------|
| `client/src/types/index.ts` | All TypeScript interfaces |
| `client/src/services/api.ts` | API client singleton |
| `client/src/stores/*.ts` | Pinia stores (one per domain) |
| `client/src/components/ui/` | Reusable UI components (shadcn-vue style) |
| `client/src/views/` | Page components |
| `client/src/router/index.ts` | Route definitions |
| `client/tailwind.config.js` | Theme configuration |

### Backend

| Path | Purpose |
|------|---------|
| `server/lib/mega_planner/` | Business logic contexts |
| `server/lib/mega_planner_web/controllers/` | API controllers |
| `server/lib/mega_planner_web/router.ex` | API routes |
| `server/priv/repo/migrations/` | Database migrations |
| `server/config/` | Environment configurations |

## Coding Conventions

### Vue/TypeScript

```vue
<!-- Always use Composition API with script setup -->
<script setup lang="ts">
import { ref, computed } from 'vue'
import type { Task } from '@/types'
import { cn } from '@/lib/utils'

// Props with TypeScript interface
interface Props {
  task: Task
  editable?: boolean
}
const props = withDefaults(defineProps<Props>(), {
  editable: false
})

// Reactive state
const isOpen = ref(false)

// Computed properties
const statusClass = computed(() => cn(
  'px-2 py-1 rounded',
  props.task.status === 'completed' && 'bg-green-100'
))
</script>
```

### Pinia Stores

```typescript
// Use setup function syntax
export const useExampleStore = defineStore('example', () => {
  const items = ref<Item[]>([])
  const loading = ref(false)

  async function fetchItems() {
    loading.value = true
    try {
      const response = await api.listItems()
      items.value = response.data
    } finally {
      loading.value = false
    }
  }

  return { items, loading, fetchItems }
})
```

### Elixir/Phoenix

```elixir
# Context module pattern (business logic)
defmodule MegaPlanner.Calendar do
  alias MegaPlanner.Repo
  alias MegaPlanner.Calendar.Task

  @task_preloads [:steps, :tags]  # Define preloads as module attributes

  def list_tasks(household_id, opts \\ []) do
    # Always scope by household_id
    from(t in Task, where: t.household_id == ^household_id)
    |> Repo.all()
    |> Repo.preload(@task_preloads)
  end
end

# Controller pattern
defmodule MegaPlannerWeb.TaskController do
  use MegaPlannerWeb, :controller
  alias MegaPlanner.Calendar

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    tasks = Calendar.list_tasks(user.household_id)
    json(conn, %{data: Enum.map(tasks, &task_to_json/1)})  # Wrap in data key
  end
end
```

## API Conventions

- All responses wrapped in `{ "data": ... }`
- Use `household_id` from authenticated user for scoping
- RESTful endpoints under `/api/`
- Auth endpoints under `/auth/`

## Domain Model

```
User (belongs to Household)
├── Tasks (with Steps, Tags)
├── Goals (with Milestones, Categories, Tags)
├── Habits (with Completions, Tags)
├── Inventory Sheets (with Items, Tags)
├── Shopping Lists (with Items, Tags)
├── Budget Sources & Entries (with Tags)
├── Notebooks (with Pages, Tags)
└── Notifications & Preferences
```

## Do's

- Follow existing patterns in the codebase
- Use types from `client/src/types/index.ts`
- Scope all queries by `household_id` on the backend
- Use the `api` singleton for HTTP requests
- Use `cn()` utility for conditional Tailwind classes
- Keep business logic in Phoenix contexts, not controllers
- Use module attributes for Ecto preloads

## Don'ts

- Don't add dependencies without clear justification
- Don't put business logic in controllers
- Don't hardcode environment values (use config)
- Don't bypass household scoping (security risk)
- Don't use `any` type in TypeScript without justification
- Don't create new UI components if existing ones suffice

## Testing

```bash
# Backend tests
cd server && mix test

# Frontend type checking
cd client && npm run build  # Includes vue-tsc
```

## Environment Variables

Backend requires (see `server/env.example`):
- `DATABASE_URL` - PostgreSQL connection
- `SECRET_KEY_BASE` - Phoenix secret
- `GUARDIAN_SECRET_KEY` - JWT signing key
- `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` - OAuth
- `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` - OAuth

Frontend uses:
- `VITE_API_URL` - Backend URL (defaults to same origin in production)

## LifeBoard-Simple (Legacy)

The `LifeBoard-Simple/` directory contains a standalone Java/JavaScript version designed for simplicity and readability. It uses:
- Pure Java HTTP server (no frameworks)
- SQLite database
- Vanilla HTML/CSS/JavaScript

This is a separate application, not integrated with the main client/server stack. Avoid modifying unless specifically requested.
