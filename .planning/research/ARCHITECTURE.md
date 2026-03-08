# Architecture Research

**Domain:** PostgreSQL → SQLite data migration for Phoenix/Ecto on Fly.io
**Researched:** 2026-03-07
**Confidence:** HIGH (verified against Fly.io official docs, ecto_sqlite3 docs, SQLite official docs, Phoenix deployment guides)

---

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MIGRATION PIPELINE                               │
│                                                                     │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │   EXPORT STAGE   │    │ TRANSFORM STAGE  │    │ IMPORT STAGE  │  │
│  │                  │    │                  │    │               │  │
│  │  Elixir Mix task │───▶│  Elixir pipeline │───▶│  SQLite3      │  │
│  │  Repo.all/stream │    │  per-table rules │    │  via Exqlite  │  │
│  │  → NDJSON files  │    │  → NDJSON files  │    │  direct SQL   │  │
│  └──────────────────┘    └──────────────────┘    └───────────────┘  │
│           │                      │                       │          │
│  Source: PostgreSQL       Type coercions:          Target: SQLite    │
│  (prod DB via tunnel)     UUID passthrough         (/data/lifeboard) │
│                           Array→JSON text                           │
│                           Map→JSON text                             │
│                           nil→NULL                                  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                     FLY.IO DEPLOYMENT                                │
│                                                                     │
│  ┌──────────────────┐    ┌──────────────────┐                       │
│  │  Fly Machine     │    │  Fly Volume      │                       │
│  │  (Docker image)  │◀──▶│  (persistent)    │                       │
│  │                  │    │                  │                       │
│  │  Phoenix app     │    │  /data/          │                       │
│  │  ecto_sqlite3    │    │  lifeboard.db    │                       │
│  └──────────────────┘    └──────────────────┘                       │
│           │                                                         │
│  Migrations run in Application.start/2 (NOT release_command)        │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| Export Mix task | Query PostgreSQL via existing Repo, write NDJSON per table | `mix migrate.export` custom Mix task using `Repo.stream` |
| Transform stage | Apply per-column type coercions, output SQLite-ready NDJSON | Separate pass or inline in export; pure Elixir functions |
| Import Mix task | Open SQLite directly, disable FK constraints, insert rows in dependency order | `mix migrate.import` using Exqlite or sqlite3 CLI |
| SQLite schema | Fresh `ecto_sqlite3`-compatible migrations (no PG-specific types) | Rewritten migrations, run before import |
| Fly.io volume | Persist SQLite file across deploys | `fly volumes create`, `[mounts]` in fly.toml |
| Application startup | Run Ecto migrations at boot (not release_command) | `MegaPlanner.Release.migrate()` in `Application.start/2` |
| Integrity verifier | Compare record counts and spot-check spot rows | Mix task querying both DBs simultaneously |

---

## The Data Transformation Pipeline

This is the most critical section. Each stage must complete before the next begins.

### Pipeline Step Sequence

```
Step 1: SCHEMA PREP (local, against fresh SQLite)
  Write new SQLite-compatible migrations
  Run: mix ecto.create && mix ecto.migrate (SQLite target)
  Verify: all tables exist, schema_migrations populated
      ↓

Step 2: EXPORT (runs against production PostgreSQL)
  mix migrate.export --output /tmp/lifeboard_export/
  Produces: one NDJSON file per table
  Each row = one JSON line, all values already string-typed UUIDs
      ↓

Step 3: TRANSFORM (runs locally against the NDJSON files)
  Inline with export or separate pass
  Per-column rules applied (see Type Coercions below)
  Output: /tmp/lifeboard_transformed/ (one NDJSON per table)
      ↓

Step 4: IMPORT (runs against local SQLite file, then uploaded)
  PRAGMA foreign_keys = OFF  (outside transaction)
  BEGIN TRANSACTION
    INSERT rows in dependency order (see Table Order below)
  COMMIT
  PRAGMA foreign_keys = ON
      ↓

Step 5: VERIFY (compare PostgreSQL vs SQLite)
  mix migrate.verify
  Record counts per table must match
  Spot check 5-10 rows per table (random sample)
  FK integrity check: PRAGMA foreign_key_check
      ↓

Step 6: UPLOAD & CUTOVER (Fly.io)
  fly sftp shell → copy lifeboard.db to /data/lifeboard.db
  OR: fly ssh console → sqlite3 restore from base64 stream
  Deploy new image (SQLite adapter) during maintenance window
```

### Type Coercions

These are the concrete transformations required for this app's schema. No other tool handles them automatically.

| PostgreSQL Type | Elixir Schema Type | SQLite Stored As | Transformation |
|----------------|-------------------|-----------------|----------------|
| `uuid` (native binary) | `:binary_id` | `TEXT` (36 char, dashed) | None needed — Ecto/Postgrex returns string already; ecto_sqlite3 default `:binary_id_type` is `:string` |
| `{:array, :string}` | `{:array, :string}` | `TEXT` (JSON) | `Jason.encode!(value)` — converts `["a","b"]` to `"[\"a\",\"b\"]"` |
| `{:array, :integer}` | `{:array, :integer}` | `TEXT` (JSON) | `Jason.encode!(value)` — converts `[0,1,2]` to `"[0,1,2]"` |
| `{:array, :binary_id}` | `{:array, :binary_id}` | `TEXT` (JSON) | `Jason.encode!(value)` — UUID strings already; produces `["uuid1","uuid2"]` |
| `:map` | `:map` | `TEXT` (JSON) | `Jason.encode!(value)` — maps serialize directly |
| `:jsonb` (array of maps) | `{:array, :map}` | `TEXT` (JSON) | `Jason.encode!(value)` — already a list of maps |
| `:jsonb` (single map) | `:map` | `TEXT` (JSON) | `Jason.encode!(value)` |
| `nil` | any nullable | `NULL` | Pass through as `nil`; do not encode `"null"` string |
| `:decimal` | `:decimal` | `TEXT` | `Decimal.to_string(value)` — SQLite stores as text, ecto_sqlite3 handles casting |
| `:date` | `:date` | `TEXT` (`"YYYY-MM-DD"`) | `Date.to_iso8601(value)` |
| `:utc_datetime` | `:utc_datetime` | `TEXT` (ISO 8601) | `DateTime.to_iso8601(value)` |
| `:time` | `:time` | `TEXT` (`"HH:MM:SS"`) | `Time.to_iso8601(value)` |
| `:boolean` | `:boolean` | `INTEGER` (0/1) | SQLite stores as 0/1; ecto_sqlite3 handles this automatically |

**Columns affected in this app:**

| Table | Column | PG Type | Action |
|-------|--------|---------|--------|
| `task_templates` | `default_steps` | `{:array, :string}` | JSON encode |
| `user_preferences` | `nav_order` | `{:array, :string}` | JSON encode |
| `user_preferences` | `dashboard_widgets` | `:jsonb` → `{:array, :map}` | JSON encode |
| `user_preferences` | `settings` | `:jsonb` → `:map` | JSON encode |
| `budget_sources` | `tags` | `{:array, :string}` | JSON encode |
| `budget_sources` | `recurrence_rule` | `:map` | JSON encode |
| `habits` | `days_of_week` | `{:array, :integer}` | JSON encode |
| `goals` | `linked_task_ids` | `{:array, :binary_id}` | JSON encode |
| `habit_inventories` | `linked_inventory_ids` | `{:array, :binary_id}` | JSON encode |
| `brands` | `default_tags` | `{:array, :binary_id}` | JSON encode |
| `tasks` | `recurrence_rule` | `:map` | JSON encode |
| `notification_preferences` | `push_subscription` | `:map` | JSON encode |
| `notifications` | `data` | `:map` | JSON encode |
| `inventory_sheets` | `columns` | `:map` | JSON encode |
| `inventory_items` | `custom_fields` | `:map` | JSON encode |
| `format_corrections` | `preference_notes` | `:map` | JSON encode |

### Table Import Ordering

SQLite enforces FK constraints per-connection (when `PRAGMA foreign_keys = ON`). Since we disable FKs during import, ordering is less critical — but establishing it correctly guards against future issues and means we can optionally run with FKs on.

**Dependency tiers (import in this order):**

```
Tier 1 (no FKs):
  users, tags, households

Tier 2 (depends on Tier 1):
  household_invitations → households
  user_preferences → users
  notification_preferences → users
  notifications → users
  tasks (no parent_task_id) → users, households
  inventory_sheets → users, households
  budget_sources → users, households
  notebooks → users, households
  goals → users, households
  habits → users, households
  task_templates → users, households
  shopping_lists → households
  stores → households
  brands → households
  units → (none)
  drivers → households

Tier 3 (depends on Tier 2):
  task_steps → tasks
  tasks_tags → tasks, tags
  goal_milestones → goals
  goal_categories → goals
  goal_status_changes → goals, goal_categories
  habit_completions → habits
  habit_inventories → habits
  shopping_list_items → shopping_lists, inventory_items, households
  budget_entries → budget_sources, users, households
  trips → stores, drivers
  stops → trips, stores
  purchases → trips, stops, inventory_items, brands
  inventory_items → inventory_sheets, brands

Tier 4 (depends on Tier 3):
  purchases_tags → purchases, tags
  budget_sources_tags → budget_sources, tags (if exists)
  budget_entries → purchases (backfill link)
  format_corrections → brands, units
  milestone_templates → (households)
  text_templates → (households)
  tax_indicator_meanings → (none)
```

**Self-referential table:** `tasks.parent_task_id` references `tasks`. Import all tasks first with `parent_task_id = NULL`, then run a second UPDATE pass to set `parent_task_id` values from a temporary mapping table.

---

## Recommended Project Structure

```
server/
├── lib/
│   └── mix/
│       └── tasks/
│           ├── migrate.export.ex     # Step 2: dump PG → NDJSON
│           ├── migrate.transform.ex  # Step 3: coerce types (may be inline)
│           ├── migrate.import.ex     # Step 4: load NDJSON → SQLite
│           └── migrate.verify.ex     # Step 5: integrity checks
├── priv/
│   └── repo/
│       └── migrations/
│           └── (all migrations rewritten for SQLite)
└── config/
    ├── config.exs       # updated: remove PG-specific generator config
    ├── dev.exs          # updated: SQLite database path
    ├── prod.exs         # updated: SQLite database path
    └── runtime.exs      # updated: DATABASE_PATH not DATABASE_URL
```

---

## Architectural Patterns

### Pattern 1: Elixir Mix Task Export (not pg_dump)

**What:** Write a `mix migrate.export` task that uses the existing `MegaPlanner.Repo` (PostgreSQL) to `Repo.stream` every table and writes one NDJSON file per table.

**Why not pg_dump:** pg_dump's `--data-only` SQL output uses PostgreSQL array literal syntax (`{a,b,c}`), which SQLite cannot consume. Ecto gives us typed Elixir values (proper lists, maps) that serialize cleanly to JSON.

**Why not Sequel gem:** Sequel copies PostgreSQL array syntax as strings (`{item1,item2}`) requiring a second transformation step. The Elixir approach gets properly decoded values from Postgrex automatically.

**Trade-offs:** Requires running Elixir code against production DB (needs SSH tunnel or `fly ssh console`). Slower than pg_dump for very large tables, but this app has a personal household dataset so row counts are small.

**Pattern:**
```elixir
# lib/mix/tasks/migrate.export.ex
defmodule Mix.Tasks.Migrate.Export do
  use Mix.Task

  @tables [
    {"users", MegaPlanner.Accounts.User},
    {"households", MegaPlanner.Households.Household},
    # ... all tables in dependency tier order
  ]

  def run([output_dir]) do
    Mix.Task.run("app.start")
    File.mkdir_p!(output_dir)

    Enum.each(@tables, fn {table_name, schema} ->
      path = Path.join(output_dir, "#{table_name}.ndjson")
      file = File.open!(path, [:write, :utf8])

      MegaPlanner.Repo.transaction(fn ->
        MegaPlanner.Repo.stream(schema)
        |> Stream.each(fn row ->
          json = row |> to_export_map() |> Jason.encode!()
          IO.puts(file, json)
        end)
        |> Stream.run()
      end, timeout: :infinity)

      File.close(file)
      Mix.shell().info("Exported #{table_name}")
    end)
  end

  # Coerce all PG-specific types to SQLite-compatible values
  defp to_export_map(row) do
    row
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Enum.map(fn {k, v} -> {k, coerce(v)} end)
    |> Map.new()
  end

  defp coerce(nil), do: nil
  defp coerce(v) when is_list(v), do: Jason.encode!(v)
  defp coerce(v) when is_map(v) and not is_struct(v), do: Jason.encode!(v)
  defp coerce(%Decimal{} = v), do: Decimal.to_string(v)
  defp coerce(%Date{} = v), do: Date.to_iso8601(v)
  defp coerce(%DateTime{} = v), do: DateTime.to_iso8601(v)
  defp coerce(%Time{} = v), do: Time.to_iso8601(v)
  defp coerce(v), do: v
end
```

### Pattern 2: Direct SQLite Import via Exqlite

**What:** The import task opens the SQLite file directly using Exqlite (the driver under ecto_sqlite3), disables FK enforcement outside any transaction, then bulk-inserts rows.

**Why not via Ecto changesets:** Changesets trigger validations, callbacks, and timestamps. For a data migration you want a direct path: SQL INSERT statements with exact values from the source.

**Trade-offs:** More verbose (manual SQL), but gives full control over insert order, batch size, and error reporting.

**Pattern:**
```elixir
# Critical SQLite import sequence
defp import_table(conn, table_name, ndjson_path) do
  rows = File.stream!(ndjson_path)
    |> Enum.map(&Jason.decode!/1)

  # Build parameterized INSERT
  [first | _] = rows
  columns = Map.keys(first) |> Enum.join(", ")
  placeholders = Map.keys(first) |> Enum.map(fn _ -> "?" end) |> Enum.join(", ")
  sql = "INSERT INTO #{table_name} (#{columns}) VALUES (#{placeholders})"

  Enum.each(rows, fn row ->
    values = Map.values(row)
    Exqlite.Sqlite3.execute(conn, sql, values)
  end)
end

# Wrap all imports:
# PRAGMA foreign_keys = OFF   <- MUST be outside BEGIN
# BEGIN TRANSACTION
# ... all inserts ...
# COMMIT
# PRAGMA foreign_keys = ON    <- MUST be outside COMMIT
```

### Pattern 3: Migrate Startup in Application.start/2

**What:** Move `MegaPlanner.Release.migrate()` from the `release_command` shell script to `Application.start/2` so it runs after the volume is mounted.

**Why:** Fly.io's `release_command` runs on a temporary machine that does NOT have volumes mounted. SQLite lives on a volume. The migration will fail silently or error.

**Critical:** Remove `release_command = '/app/bin/migrate'` from `fly.toml` entirely.

**Pattern:**
```elixir
# lib/mega_planner/application.ex
def start(_type, _args) do
  # Runs migrations before supervisor starts children
  # Volume is guaranteed mounted at this point
  MegaPlanner.Release.migrate()

  children = [
    MegaPlanner.Repo,
    MegaPlannerWeb.Endpoint,
    # ...
  ]
  Supervisor.start_link(children, strategy: :one_for_one, name: MegaPlanner.Supervisor)
end
```

---

## Fly.io Volume Configuration

### Exact fly.toml Changes

**Current `server/fly.toml` (PostgreSQL):**
```toml
app = 'mega-planner-api'
primary_region = 'iad'

[build]

[deploy]
  release_command = '/app/bin/migrate'   # DELETE THIS

[env]
  PHX_HOST = 'mega-planner-api.fly.dev'
  PORT = '4000'
  # DATABASE_URL set as secret — REMOVE from secrets, replace with DATABASE_PATH
```

**Target `server/fly.toml` (SQLite):**
```toml
app = 'mega-planner-api'
primary_region = 'iad'

[build]

# [deploy] section removed — no release_command for SQLite

[env]
  PHX_HOST = 'mega-planner-api.fly.dev'
  PORT = '4000'
  DATABASE_PATH = '/data/lifeboard.db'

[mounts]
  source = 'lifeboard_data'
  destination = '/data'

[http_service]
  internal_port = 4000
  force_https = true
  auto_stop_machines = 'stop'
  auto_start_machines = true
  min_machines_running = 0
  processes = ['app']

  [http_service.concurrency]
    type = 'connections'
    hard_limit = 1000
    soft_limit = 1000

  [[http_service.checks]]
    interval = '10s'
    timeout = '2s'
    grace_period = '5s'
    method = 'GET'
    path = '/api/health'

[[vm]]
  memory = '1gb'
  cpu_kind = 'shared'
  cpus = 1
```

### Volume Creation Command

```bash
fly volumes create lifeboard_data \
  --region iad \
  --size 3 \
  --app mega-planner-api
```

Volume name `lifeboard_data` must match `source` in `[mounts]` exactly. Only alphanumeric and underscores allowed.

### Dockerfile Changes Required

Add `libsqlite3-dev` to the build stage and `libsqlite3-0` to the runner stage (needed by Exqlite's NIF):

```dockerfile
# Builder stage — add sqlite dev headers
RUN apt-get update -y && apt-get install -y build-essential git libsqlite3-dev \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Runner stage — add sqlite runtime library
RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates libsqlite3-0 \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*
```

The `/data` directory does not need to be created in the Dockerfile — the Fly volume mount creates it automatically.

### Secrets Update

```bash
# Remove old PostgreSQL secret
fly secrets unset DATABASE_URL --app mega-planner-api

# DATABASE_PATH is set as env var in fly.toml, not a secret (no credentials)
# If using secret for path override:
fly secrets set DATABASE_PATH=/data/lifeboard.db --app mega-planner-api
```

### runtime.exs Changes

```elixir
# Replace the DATABASE_URL block with:
if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /data/lifeboard.db
      """

  config :mega_planner, MegaPlanner.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    journal_mode: :wal,
    foreign_keys: :on,
    busy_timeout: 5000,
    cache_size: -64_000,
    default_transaction_mode: :immediate

  # ... rest of config unchanged
end
```

---

## Cutover and Rollback Strategy

### Cutover Sequence (Maintenance Window)

```
T-0:  Enable maintenance mode (or coordinate with household members)
      The app is a personal household tool — a 15-minute window is acceptable.

T-1:  fly ssh console -a mega-planner-api
      Confirm current PostgreSQL is healthy, get final record counts

T-2:  Run export Mix task against production PG (via fly ssh console or local tunnel):
      mix migrate.export --output /tmp/export/

T-3:  Run verification of export (count lines per file vs PG table counts)

T-4:  Locally: run transform + import into fresh SQLite file
      Verify with mix migrate.verify --sqlite /tmp/lifeboard.db

T-5:  Upload SQLite file to Fly volume:
      # Option A: fly sftp (if available)
      fly sftp shell -a mega-planner-api
      > put /tmp/lifeboard.db /data/lifeboard.db

      # Option B: base64 stream via ssh console
      base64 /tmp/lifeboard.db | fly ssh console -a mega-planner-api \
        -C "base64 -d > /data/lifeboard.db"

T-6:  Deploy new image (SQLite adapter, updated fly.toml):
      fly deploy --app mega-planner-api

T-7:  Smoke test: hit /api/health, log in, verify one record from each domain

T-8:  Disable maintenance mode. Migration complete.
```

### Rollback Plan

**Before cutover, the rollback window is wide open** — PostgreSQL is still running, nothing has changed in production.

**After T-6 deploy, rollback steps:**

1. Keep the old Docker image tag available (`fly releases list`)
2. Keep the PostgreSQL Fly app alive for 48 hours post-migration (do not destroy it immediately)
3. If SQLite deploy fails at T-6:
   ```bash
   fly deploy --image <previous-image-registry-tag> --app mega-planner-api
   ```
   This re-deploys the PostgreSQL image. The old `DATABASE_URL` secret must not be deleted until rollback window closes.

4. If SQLite runs but data is corrupt post-cutover:
   - Restore the SQLite file from the Fly volume snapshot (`fly volumes snapshots list <vol-id>`)
   - Or re-run the full migration pipeline from the NDJSON export files (they are preserved)

**Rollback window:** Keep PostgreSQL alive for 48 hours after successful cutover. After that, destroy the Fly PostgreSQL cluster.

---

## Data Integrity Verification

### Phase 1: Table-Level Record Counts

```elixir
# mix migrate.verify compares:
# - Repo.aggregate(table, :count) on PostgreSQL
# - Direct SQLite COUNT(*) on each table
# Expected: exact match on all ~30 tables

tables = [:users, :households, :tasks, :task_steps, :tasks_tags, ...]
Enum.each(tables, fn table ->
  pg_count = Repo.aggregate(table, :count)
  sqlite_count = sqlite_count(table)
  if pg_count != sqlite_count do
    IO.puts("MISMATCH #{table}: PG=#{pg_count} SQLite=#{sqlite_count}")
  end
end)
```

### Phase 2: Structural Integrity

```sql
-- Run after import, before deploying
PRAGMA foreign_key_check;
-- Must return zero rows (no FK violations)

PRAGMA integrity_check;
-- Must return "ok"
```

### Phase 3: Row-Level Spot Checks

For each table, fetch 5 rows by known IDs from PostgreSQL and verify same values exist in SQLite:

- Check UUIDs are string format (36 chars with dashes), not binary
- Check JSON columns are valid JSON strings (not `{a,b}` array syntax)
- Check timestamps are ISO 8601 strings
- Check decimal values match (especially `budget_entries.amount`, `purchases.price`)

### Phase 4: Application-Level Smoke Test

After deploy:
- Login flow (Guardian JWT — tests users table)
- Load task list (tests tasks, tasks_tags, tags)
- Load budget (tests budget_entries, budget_sources)
- Load inventory (tests inventory_items, inventory_sheets, custom_fields JSON)
- Load habits (tests habits, habit_completions, days_of_week JSON)
- Load user preferences (tests nav_order, dashboard_widgets JSON)

---

## Anti-Patterns

### Anti-Pattern 1: Using release_command for SQLite Migrations

**What people do:** Keep `release_command = '/app/bin/migrate'` in fly.toml after switching to SQLite.

**Why it's wrong:** The release command runs on a temporary Fly machine that does NOT have volumes mounted. The SQLite file at `/data/lifeboard.db` does not exist on that machine. Migrations either fail with file-not-found or create a throwaway database that is discarded immediately.

**Do this instead:** Remove `release_command` from fly.toml. Call `MegaPlanner.Release.migrate()` in `Application.start/2`.

### Anti-Pattern 2: Using pg_dump for Data Export

**What people do:** `pg_dump --data-only` and try to load the SQL into SQLite.

**Why it's wrong:** pg_dump emits PostgreSQL array literals (`{item1,item2}`) and COPY commands that SQLite cannot parse. Even if you convert to INSERT statements, the array syntax is wrong for SQLite's JSON expectation.

**Do this instead:** Use Ecto's `Repo.stream` — Postgrex decodes arrays to proper Elixir lists, which `Jason.encode!` converts to valid JSON strings that ecto_sqlite3 can read back.

### Anti-Pattern 3: Toggling PRAGMA foreign_keys Inside a Transaction

**What people do:** `BEGIN; PRAGMA foreign_keys = OFF; INSERT ...; COMMIT;`

**Why it's wrong:** SQLite silently ignores PRAGMA changes inside transactions. Foreign key enforcement remains whatever it was before the transaction started, and no error is raised.

**Do this instead:** Set `PRAGMA foreign_keys = OFF` before `BEGIN`, and `PRAGMA foreign_keys = ON` after `COMMIT`.

### Anti-Pattern 4: Storing UUIDs as Binary in SQLite

**What people do:** Set `binary_id_type: :binary` in ecto_sqlite3 config thinking it matches PostgreSQL's native UUID storage.

**Why it's wrong for this migration:** The existing app has PostgreSQL returning UUIDs as strings (Ecto/Postgrex always returns them as `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"` strings). Using `:binary` in SQLite means the SQLite adapter expects to BLOB-encode these strings, causing a mismatch in how foreign keys are compared at the application level.

**Do this instead:** Leave ecto_sqlite3 at its default `binary_id_type: :string`. UUIDs are already strings at the Ecto boundary from PostgreSQL. They stay strings in SQLite TEXT columns. No conversion needed.

### Anti-Pattern 5: Destroying PostgreSQL Before Verifying SQLite

**What people do:** Immediately run `fly postgres destroy` after the SQLite deploy succeeds.

**Why it's wrong:** Latent data bugs (missed column coercions, truncated JSON) may not surface until a user hits an edge-case code path after the maintenance window.

**Do this instead:** Keep PostgreSQL running for 48 hours post-cutover. Only destroy it after confirming all application domains work correctly in production.

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Fly.io PostgreSQL | Source for export only; destroyed after cutover | Keep alive 48h post-migration as rollback option |
| Fly.io Volume | Persistent block storage mounted at `/data` | Create before deploy; one volume per machine |
| Exqlite (NIF) | C extension compiled into release | Requires `libsqlite3-dev` in build stage, `libsqlite3-0` in runner |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Export task ↔ PostgreSQL Repo | `Repo.stream` within transactions | Stream to avoid loading all rows in memory |
| Import task ↔ SQLite file | Direct Exqlite calls (bypass Ecto) | No changesets — raw SQL inserts for speed and control |
| Application ↔ SQLite (post-migration) | Normal `ecto_sqlite3` adapter | Pool size 5 recommended for single-writer SQLite |
| Application startup ↔ Migrations | `Release.migrate()` in `Application.start/2` | Replaces `release_command` pattern |

---

## Build Order (What Must Come Before What)

```
1. Schema rewrite (migrations)
   └── Must be complete before any SQLite schema is created
   └── Must be done before export (ensures you know what columns SQLite expects)

2. Adapter swap (ecto_sqlite3 in mix.exs, Repo adapter, configs)
   └── Must be complete before local testing
   └── Needed before building the Docker image

3. Local SQLite verification (dev environment)
   └── Run new migrations locally against SQLite
   └── Verify app boots and basic queries work

4. Migration tooling (Mix tasks: export, import, verify)
   └── Can be built in parallel with #2/#3
   └── Must be ready before production export

5. Fly.io volume creation
   └── Must exist before the new Docker image is deployed
   └── `fly volumes create lifeboard_data --region iad --size 3`

6. Dockerfile update (add libsqlite3)
   └── Required for the release build to succeed

7. fly.toml update (mounts, remove release_command, DATABASE_PATH env)
   └── Staged; do NOT deploy until SQLite image is ready

8. Production export + import (migration pipeline)
   └── Requires production PostgreSQL to still be running
   └── Export → Transform → Import → Verify cycle

9. Upload SQLite file to volume
   └── After verify passes

10. Deploy new image
    └── After file is uploaded and verified

11. Smoke test and cutover confirmation

12. PostgreSQL teardown (after 48h)
```

---

## Sources

- [ecto_sqlite3 official docs — Ecto.Adapters.SQLite3 v0.22.0](https://hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html) — PRAGMA defaults, binary_id_type, uuid_type configuration (HIGH confidence)
- [ecto_sqlite3 GitHub Issue #70 — binary_id_type discussion](https://github.com/elixir-sqlite/ecto_sqlite3/issues/70) — UUID encoding differences between PG and SQLite (HIGH confidence)
- [Fly.io Elixir SQLite3 guide](https://fly.io/docs/elixir/advanced-guides/sqlite3/) — fly.toml mounts syntax, migration startup pattern (HIGH confidence)
- [Fly.io volumes overview](https://fly.io/docs/volumes/overview/) — volume creation, one-to-one machine mapping (HIGH confidence)
- [SQLite official docs — PRAGMA foreign_keys](https://sqlite.org/foreignkeys.html) — cannot toggle inside transaction (HIGH confidence)
- [SQLite official docs — PRAGMA statements](https://sqlite.org/pragma.html) — full PRAGMA reference (HIGH confidence)
- [Fly.io community — Migration in sqlite3 on volume fails](https://community.fly.io/t/migration-in-sqlite3-on-volume-fails/3818) — release_command does not have volume access (HIGH confidence)
- [Phoenix + SQLite Deployment tips gist](https://gist.github.com/mcrumm/98059439c673be7e0484589162a54a01) — Chris McCord endorsed pattern for `Application.start/2` migrations (MEDIUM confidence)
- [Fly.io SQLite docs — Ruby/Rails guide](https://fly.io/docs/rails/advanced-guides/sqlite3/) — volume mount syntax cross-reference (HIGH confidence)

---

*Architecture research for: PostgreSQL → SQLite migration, Phoenix/Ecto on Fly.io*
*Researched: 2026-03-07*
