# Codebase Structure

**Analysis Date:** 2026-03-07

## Directory Layout

```
lifeboard-mono/
├── client/                        # Vue 3 frontend application
│   ├── src/
│   │   ├── assets/               # Static assets and global styles
│   │   ├── components/           # Reusable Vue components (domain-organized)
│   │   ├── composables/          # Stateful logic composition functions
│   │   ├── lib/                  # Utility functions and helpers
│   │   ├── router/               # Vue Router configuration
│   │   ├── services/             # API client
│   │   ├── stores/               # Pinia state management (domain-based)
│   │   ├── types/                # TypeScript type definitions
│   │   ├── utils/                # Utility modules
│   │   ├── views/                # Page-level components (route views)
│   │   ├── App.vue               # Root component
│   │   └── main.ts               # Entry point
│   ├── tests/                    # End-to-end tests (Playwright)
│   ├── public/                   # Static files (favicon, manifests)
│   ├── index.html                # HTML template
│   ├── package.json              # Dependencies
│   ├── vite.config.ts            # Vite build configuration
│   ├── tsconfig.json             # TypeScript configuration
│   ├── tailwind.config.js        # Tailwind CSS configuration
│   └── playwright.config.ts      # E2E test configuration
│
├── server/                        # Phoenix/Elixir backend
│   ├── lib/
│   │   ├── mega_planner/         # Business logic contexts
│   │   │   ├── accounts/         # User management
│   │   │   ├── budget/           # Budget domain
│   │   │   ├── calendar/         # Calendar and tasks domain
│   │   │   ├── goals/            # Goals and habits domain
│   │   │   ├── households/       # Household/multi-tenancy
│   │   │   ├── inventory/        # Inventory tracking
│   │   │   ├── notes/            # Notes/notebooks domain
│   │   │   ├── notifications/    # Notification preferences
│   │   │   ├── receipts/         # Receipts and trip tracking
│   │   │   ├── tags/             # Tag management
│   │   │   ├── templates/        # Text template system
│   │   │   ├── *.ex              # Context modules (e.g., calendar.ex)
│   │   │   ├── application.ex    # Supervision tree
│   │   │   ├── repo.ex           # Database interface
│   │   │   └── search.ex         # Global search logic
│   │   └── mega_planner_web/     # Phoenix web layer
│   │       ├── controllers/      # HTTP controllers
│   │       ├── plugs/            # Custom middleware
│   │       ├── endpoint.ex       # HTTP endpoint
│   │       ├── router.ex         # Route definitions
│   │       └── telemetry.ex      # Observability setup
│   ├── priv/
│   │   ├── repo/
│   │   │   ├── migrations/       # Database migrations
│   │   │   └── seeds.exs         # Seed data
│   │   └── static/               # Static assets
│   ├── test/                     # Unit and integration tests
│   ├── config/                   # Configuration files
│   ├── mix.exs                   # Mix project definition
│   ├── mix.lock                  # Locked dependency versions
│   └── Dockerfile                # Docker image for backend
│
├── .planning/                     # Planning and documentation
│   └── codebase/                 # Codebase analysis documents
├── docker-compose.yml            # Local database setup
├── package.json                  # Monorepo metadata
└── README.md                     # Project overview

```

## Directory Purposes

**client/src/assets/:**
- Purpose: Global styles and static assets
- Contains: `index.css` (Tailwind imports), SVG icons, fonts
- Key files: `client/src/assets/index.css`

**client/src/components/:**
- Purpose: Reusable Vue components organized by feature domain
- Contains: Feature components and shared UI primitives
- Subdirectories: `budget/`, `calendar/`, `dashboard/`, `inventory/`, `layout/`, `notes/`, `reports/`, `shopping/`, `timer/`, `ui/`, `shared/`
- Key files: `client/src/components/layout/AppShell.vue` (main layout), `client/src/components/shared/` (dialogs, modals)

**client/src/composables/:**
- Purpose: Reusable stateful logic extracted from components
- Contains: Vue composition functions for cross-cutting concerns
- Key files: `client/src/composables/useCRUDStore.ts` (generic CRUD wrapper), `client/src/composables/useKeyboardShortcuts.ts`, `client/src/composables/useModal.ts`

**client/src/lib/:**
- Purpose: Generic utilities and helpers
- Contains: Pure functions for formatting, CSS utilities
- Key files: `client/src/lib/utils.ts` (cn function, formatCurrency, formatDate, debounce)

**client/src/router/:**
- Purpose: Vue Router configuration
- Contains: Route definitions, auth guards, prefetching
- Key files: `client/src/router/index.ts` (all routes defined here)

**client/src/services/:**
- Purpose: API client and external service integration
- Contains: HTTP client with token management, API methods for all domains
- Key files: `client/src/services/api.ts` (ApiClient class, 38KB, handles all API communication)

**client/src/stores/:**
- Purpose: Pinia state management stores, one per domain
- Contains: Stores for Calendar, Budget, Inventory, Goals, etc.
- Key files: `client/src/stores/auth.ts` (user auth state), individual domain stores

**client/src/types/:**
- Purpose: TypeScript type definitions
- Contains: Interfaces matching backend data models
- Key files: `client/src/types/index.ts` (all type definitions)

**client/src/utils/:**
- Purpose: Domain-specific utilities
- Contains: Formatting, unit conversion, prefetching logic
- Key files: `client/src/utils/prefetch.ts` (route-level data prefetching)

**client/src/views/:**
- Purpose: Page-level components mounted by router
- Contains: View components for each route, organized by domain
- Structure: `auth/`, `budget/`, `calendar/`, `goals/`, `inventory/`, `notes/`, `reports/`, `settings/`, `tags/`
- Key files: `client/src/views/DashboardView.vue` (home page)

**server/lib/mega_planner/:**
- Purpose: Business logic organized as domain contexts
- Contains: One context module per domain (Calendar, Budget, Inventory, etc.)
- Context pattern: Each context (e.g., `calendar.ex`) exports public functions like `list_tasks/2`, `create_task/1`, uses `Repo` for persistence
- Key files: `calendar.ex`, `budget.ex`, `inventory.ex`, `accounts.ex`, `goals.ex`, `households.ex`

**server/lib/mega_planner_web/controllers/:**
- Purpose: HTTP request handlers
- Contains: One controller per resource (TaskController, BudgetController, etc.)
- Pattern: Actions call context functions, return via conn with JSON serialization
- Key files: `task_controller.ex`, `budget_entry_controller.ex`, `receipt_upload_controller.ex` (18KB, handles receipt image parsing)

**server/lib/mega_planner_web/plugs/:**
- Purpose: Custom middleware
- Contains: Authentication, test mode bypass, CORS
- Key files: `AuthPipeline` (Guardian JWT validation), `TestModeAuth` (test bypass)

**server/priv/repo/migrations/:**
- Purpose: Database schema evolution
- Contains: Ecto migration files, one per schema change
- Pattern: Files named with timestamp (e.g., `20260206051800_add_usage_mode_to_inventory_items.exs`)

## Key File Locations

**Entry Points:**

- `client/src/main.ts` - Frontend entry point, creates Vue app and mounts
- `client/index.html` - HTML template with script src pointing to main.ts
- `server/lib/mega_planner/application.ex` - Backend supervision tree startup
- `server/lib/mega_planner_web/endpoint.ex` - Phoenix HTTP server configuration

**Configuration:**

- `client/vite.config.ts` - Build tool config, API proxy setup
- `client/tsconfig.json` - TypeScript compilation settings
- `client/tailwind.config.js` - Tailwind CSS customization
- `server/config/config.exs` - Mix config, database, auth settings
- `server/mix.exs` - Elixir dependencies

**Core Logic:**

- `client/src/services/api.ts` - All API client methods (tasks, budget, inventory, etc.)
- `server/lib/mega_planner_web/router.ex` - All route definitions
- `server/lib/mega_planner/calendar.ex` - Task management logic
- `server/lib/mega_planner/budget.ex` - Budget source and entry logic
- `server/lib/mega_planner/inventory.ex` - Inventory sheet and item logic

**Testing:**

- `client/tests/` - Playwright end-to-end tests
- `server/test/` - ExUnit unit and integration tests
- `client/playwright.config.ts` - E2E test configuration

## Naming Conventions

**Files:**

- Vue components: PascalCase (e.g., `TaskCard.vue`, `BudgetView.vue`)
- TypeScript files: camelCase or PascalCase by convention (e.g., `api.ts`, `calendar.ts`)
- Elixir files: snake_case (e.g., `task_controller.ex`, `budget_entry.ex`)
- Test files: suffixed with `.test.ts` or `.spec.ts` (frontend), `_test.exs` (backend)

**Directories:**

- Feature domains: lowercase singular (e.g., `calendar/`, `budget/`, `inventory/`)
- UI components: `ui/` for primitive components, feature-named subdirs for domain components
- Stores: domain names matching context names (e.g., `calendar.ts`, `budget.ts`)

**Exports:**

- Vue components: Default export (SFC)
- Stores: Named export `use{DomainStore}` (e.g., `useCalendarStore`)
- Composables: Named export `use{Feature}` (e.g., `useCRUDStore`)
- Types: Named exports (e.g., `export interface Task { ... }`)
- Elixir modules: Module name matching file (e.g., `MegaPlanner.Calendar.Task` in `calendar/task.ex`)

## Where to Add New Code

**New Feature (Complete Domain):**
- Backend context: `server/lib/mega_planner/{domain}/{entities}.ex`
- Backend controller: `server/lib/mega_planner_web/controllers/{entity}_controller.ex`
- Backend routes: Add scope in `server/lib/mega_planner_web/router.ex`
- Database: Create migration in `server/priv/repo/migrations/`
- Frontend store: `client/src/stores/{domain}.ts`
- Frontend views: `client/src/views/{domain}/` subdirectory
- Frontend components: `client/src/components/{domain}/` subdirectory
- Frontend types: Add to `client/src/types/index.ts`
- Frontend router: Add routes to `client/src/router/index.ts`

**New Component/Module:**
- Backend schema: `server/lib/mega_planner/{context}/{entity}.ex`
- Backend context function: Add function to `server/lib/mega_planner/{context}.ex`
- Backend controller action: `server/lib/mega_planner_web/controllers/{entity}_controller.ex`
- Frontend component: `client/src/components/{domain}/{ComponentName}.vue`
- Frontend types: Update `client/src/types/index.ts` with interface

**Utilities:**
- Shared helpers (formatting, etc.): `client/src/lib/utils.ts`
- Domain-specific utils: `client/src/utils/{purpose}.ts` (e.g., `prefetch.ts`)
- Composables (stateful): `client/src/composables/use{Feature}.ts`
- Backend utilities: Module in `server/lib/mega_planner/` without context structure

## Special Directories

**client/tests/:**
- Purpose: Playwright end-to-end tests
- Generated: No
- Committed: Yes
- Organization: Mirrors routes/features

**server/priv/repo/migrations/:**
- Purpose: Database schema versioning
- Generated: `mix ecto.gen.migration` command creates new migrations
- Committed: Yes
- Files: Immutable after creation; never modify existing migrations

**client/public/ and server/priv/static/:**
- Purpose: Static files served directly (no processing)
- Generated: No
- Committed: Yes
- Files: Icons, manifests, images

**server/rel/:**
- Purpose: Release configuration for production deployment
- Generated: By `mix release` command
- Committed: Yes (config only, not built artifacts)

**.planning/codebase/:**
- Purpose: Codebase analysis and documentation
- Generated: By GSD mapping agent
- Committed: Yes (documents only, tracking architecture decisions)

