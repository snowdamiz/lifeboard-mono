# Architecture

**Analysis Date:** 2026-03-07

## Pattern Overview

**Overall:** Three-tier monorepo architecture with clear separation of concerns. Client-server separation using REST API with OAuth authentication. Backend uses domain-driven design (contexts), frontend uses component-based architecture with state management via Pinia.

**Key Characteristics:**
- Client (Vue 3 + TypeScript) communicates via REST API with Phoenix backend (Elixir)
- Feature domains organized as contexts on backend (Calendar, Budget, Inventory, Goals, etc.)
- Component-driven frontend with reusable UI component library (shadcn-vue)
- Token-based authentication (JWT via Guardian) with refresh mechanism
- Household-based multi-tenant data model

## Layers

**Presentation Layer (Frontend):**
- Purpose: Vue 3 UI components, views, and state management
- Location: `client/src/`
- Contains: Vue components (`.vue` files), router, stores (Pinia), composables
- Depends on: API service (`services/api.ts`), Pinia stores, Vue Router
- Used by: End users via browser at `http://localhost:5173`

**API Gateway Layer:**
- Purpose: RESTful API endpoints, OAuth authentication, request/response transformation
- Location: `server/lib/mega_planner_web/`
- Contains: Controllers, plugs (middleware), router definitions, Ueberauth configuration
- Depends on: Business logic contexts, Ecto models, Guardian JWT
- Used by: Frontend client, iCal feed consumers

**Business Logic Layer (Contexts):**
- Purpose: Domain logic, data validation, business rules, query building
- Location: `server/lib/mega_planner/` (one context per domain)
- Contains: Context modules (Calendar, Budget, Inventory, Goals, Accounts, etc.), each managing related schemas
- Depends on: Ecto models, Repo (database), other contexts as needed
- Used by: Controllers, other contexts

**Data Layer:**
- Purpose: Persistence and database queries
- Location: `server/lib/mega_planner/` (Ecto schemas) + `server/priv/repo/`
- Contains: Ecto schemas (Task, Budget.Entry, etc.), migrations, seeds
- Depends on: PostgreSQL database
- Used by: Business logic contexts via Repo

## Data Flow

**User Authentication Flow:**

1. User visits `/login` (public route)
2. Clicks OAuth provider (Google/GitHub)
3. Frontend redirects to `GET /auth/:provider` on backend
4. Backend uses Ueberauth to redirect to OAuth provider
5. OAuth provider redirects back to `GET /auth/:provider/callback`
6. Backend validates, creates/updates User and household
7. Backend generates JWT tokens (access + refresh)
8. Backend redirects to `http://localhost:5173/auth/callback?token=...`
9. Frontend's `CallbackView.vue` extracts token, stores in localStorage
10. API client (`services/api.ts`) sets tokens on all requests
11. Route guard in `router/index.ts` checks `useAuthStore.isAuthenticated`

**API Request Flow:**

1. Frontend component calls API method (e.g., `api.listTasks()`)
2. API client adds access token in Authorization header
3. Request goes to Phoenix endpoint at `POST /api/*`
4. Router pipes through `:api` pipeline (JSON parsing) and `:api_auth` (Guardian token validation)
5. Controller receives authenticated request with `current_user` in assigns
6. Controller calls context method (e.g., `Calendar.list_tasks()`)
7. Context builds query, calls `Repo.all()` on database
8. Results serialized via JSON view, returned to frontend
9. If token expired, API client catches 401, calls `GET /auth/refresh`
10. Token refreshed, request retried automatically

**Data Mutation Flow:**

1. Frontend component dispatches action to Pinia store
2. Store calls API create/update/delete method
3. API validates changeset on backend
4. If valid, persisted to database via Repo
5. Serialized result returned to frontend
6. Store updates local state with new data
7. Component reactively updates UI

**State Management:**

- Frontend: Pinia stores (one per domain: `calendar.ts`, `budget.ts`, `inventory.ts`, etc.)
- Each store manages items array, loading state, error state
- Stores use `useCRUDStore()` composable pattern for common CRUD operations
- Route-level prefetching via `router.beforeResolve()` triggers data loading before navigation
- Household context automatically fetched after auth via `useHouseholdStore`

## Key Abstractions

**Context (Backend):**
- Purpose: Domain-specific business logic and database operations
- Examples: `server/lib/mega_planner/calendar.ex`, `server/lib/mega_planner/budget.ex`, `server/lib/mega_planner/inventory.ex`
- Pattern: Module defines public functions for CRUD/queries, imports Ecto.Query, uses Repo for persistence

**Schema (Backend):**
- Purpose: Database model definition and validation
- Examples: `server/lib/mega_planner/calendar/task.ex`, `server/lib/mega_planner/budget/source.ex`
- Pattern: Uses Ecto.Schema with changeset functions for validation

**Controller (Backend):**
- Purpose: HTTP request handling and response formatting
- Examples: `server/lib/mega_planner_web/controllers/task_controller.ex`
- Pattern: Receives request, calls context functions, returns JSON via FallbackController or error handler

**Pinia Store (Frontend):**
- Purpose: Centralized state for a feature domain
- Examples: `client/src/stores/calendar.ts`, `client/src/stores/budget.ts`
- Pattern: Composition API with `defineStore()`, uses `useCRUDStore()` for boilerplate reduction

**Composable (Frontend):**
- Purpose: Reusable stateful logic, composition of UI/business concerns
- Examples: `client/src/composables/useCRUDStore.ts`, `client/src/composables/useKeyboardShortcuts.ts`
- Pattern: Functions returning reactive state and methods, composable names start with `use`

**Component (Frontend):**
- Purpose: Reusable UI elements
- Examples: `client/src/components/ui/button/Button.vue`, `client/src/components/calendar/TaskCard.vue`
- Pattern: Single-file components with `<script setup>` in TypeScript

## Entry Points

**Frontend Entry Point:**
- Location: `client/src/main.ts`
- Triggers: `npm run dev` or build process
- Responsibilities: Creates Vue app, registers Pinia, mounts router, loads global CSS

**Frontend Root Component:**
- Location: `client/src/App.vue`
- Triggers: After main.ts mounts
- Responsibilities: Renders RouterView, initializes global keyboard shortcuts

**Frontend Router:**
- Location: `client/src/router/index.ts`
- Triggers: On every navigation
- Responsibilities: Route definitions, auth guard, data prefetching

**Backend Entry Point:**
- Location: `server/lib/mega_planner/application.ex`
- Triggers: `mix phx.server` or release startup
- Responsibilities: Starts supervision tree, initializes Telemetry, PubSub, Repo, Endpoint

**Backend Router:**
- Location: `server/lib/mega_planner_web/router.ex`
- Triggers: On every HTTP request
- Responsibilities: Route definitions, pipeline definitions, scope grouping

**Backend API Endpoint:**
- Location: `server/lib/mega_planner_web/endpoint.ex`
- Triggers: Phoenix starts endpoint in supervision tree
- Responsibilities: HTTP server configuration, CORS, logging, socket setup

## Error Handling

**Strategy:** Two-tier error handling with context-level validation and controller-level HTTP formatting

**Patterns:**

- **Validation Errors (Backend):** Ecto changeset errors collected in context functions, returned as `{:error, changeset}` tuple, FallbackController formats as 422 with field errors
- **Authorization Errors (Backend):** Guardian plug returns 401 Unauthorized if token missing/invalid, AuthPipeline plug handles this
- **API Errors (Frontend):** API client catches HTTP errors, checks for 401 (token refresh), logs other errors, re-throws for component handling
- **Component Error Handling (Frontend):** Try-catch in event handlers, Pinia store error ref for async operations, error boundary patterns via parent component error handling

## Cross-Cutting Concerns

**Logging:**
- Backend: Logger.debug/info/error in contexts for business logic flow
- Frontend: console.log during development, silent in production

**Validation:**
- Backend: Ecto changesets define allowed fields, type conversions, constraints, unique indexes
- Frontend: TypeScript types enforce shape, optional runtime validation in forms via API feedback

**Authentication:**
- Backend: Guardian configures JWT signing, Token refresh endpoint validates refresh_token
- Frontend: localStorage stores access_token + refresh_token, API client injects Authorization header, router guards redirect unauthenticated users to /login
- Multi-tenant: Household ID associated with user, queries filtered by household_id to prevent cross-household access

**Authorization:**
- Backend: Controllers assume `current_user` in assigns after AuthPipeline; contexts filter by household_id implicitly
- Frontend: No client-side authorization; all protected routes require valid token

**CORS:**
- Backend: CorsPlug in endpoint allows cross-origin requests from localhost:5173 in development
- Frontend: Vite proxy configuration routes /api and /auth/refresh to http://localhost:4000

