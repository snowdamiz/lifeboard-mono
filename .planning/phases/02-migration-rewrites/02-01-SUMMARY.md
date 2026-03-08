---
phase: 02-migration-rewrites
plan: "01"
subsystem: database
tags: [ecto, sqlite, migrations, ecto_sqlite3, partial-index]

# Dependency graph
requires:
  - phase: 01-dependency-config
    provides: ecto_sqlite3 adapter configured, repo adapter updated to Ecto.Adapters.SQLite3
provides:
  - SQLite-compatible partial unique index in migration 04 using raw SQL execute with WHERE purchased = 0
  - SQLite-compatible JSON column types in migration 17 using {:array, :map} and :map instead of :jsonb
affects:
  - 02-migration-rewrites (plan 02 — migration 13 PL/pgSQL rewrite can now proceed independently)
  - 03-schema-updates (schema field declarations must match migration column types)
  - 04-data-export-import (migrations establish final table structure)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SQLite boolean partial index: use WHERE column = 0 (not WHERE column = false) in raw SQL"
    - "SQLite JSON arrays: declare as {:array, :map} with default: [] (not :jsonb with default: \"[]\")"
    - "SQLite JSON objects: declare as :map with default: %{} (not :jsonb with default: \"{}\")"
    - "Raw execute SQL in migrations requires def up/def down (not def change) for reversibility"

key-files:
  created: []
  modified:
    - server/priv/repo/migrations/20260101000004_create_inventory.exs
    - server/priv/repo/migrations/20260101000017_create_user_preferences.exs

key-decisions:
  - "Partial unique index for shopping_list_items uses raw SQL execute (not Ecto DSL where: option) because SQLite requires WHERE purchased = 0 (integer) not WHERE purchased = false (PostgreSQL boolean)"
  - "Migration 04 converted from def change to def up/def down because raw execute SQL blocks cannot be auto-reversed by Ecto"
  - "dashboard_widgets uses {:array, :map} not :jsonb — ecto_sqlite3 serializes the Elixir list to JSON text; string default '[]' would store literal string instead of empty array"
  - "settings uses :map not :jsonb — ecto_sqlite3 serializes %{} to JSON; string default '{}' would store literal string instead of empty map"

patterns-established:
  - "Pattern 1: SQLite partial indexes must use raw SQL via execute/1 with integer boolean values (0/1)"
  - "Pattern 2: Elixir value defaults ([], %{}) required for JSON column types — string form bypasses ecto_sqlite3 serialization"

requirements-completed: [MIGR-02, MIGR-03]

# Metrics
duration: 1min
completed: 2026-03-08
---

# Phase 02 Plan 01: Migration Rewrites (Inventory + User Preferences) Summary

**SQLite-compatible partial unique index via raw SQL (WHERE purchased = 0) and JSON column type replacements ({:array, :map}, :map) replacing PostgreSQL-specific :jsonb in migrations 04 and 17**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-08T02:23:17Z
- **Completed:** 2026-03-08T02:24:18Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Migration 04 (CreateInventory) converted from `def change` to `def up`/`def down` with raw SQL partial unique index using `WHERE purchased = 0` — compatible with SQLite's integer boolean representation
- Migration 17 (CreateUserPreferences) updated: `:jsonb` replaced with `{:array, :map}` (dashboard_widgets) and `:map` (settings), with Elixir value defaults (`[]`, `%{}`) instead of JSON string literals
- `mix compile --warnings-as-errors` passes cleanly after both changes; no `:jsonb` or `purchased = false` remain in migration files

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite partial index in migration 04 (MIGR-03)** - `09646a8` (fix)
2. **Task 2: Replace :jsonb types in migration 17 (MIGR-02)** - `f40236e` (fix)

## Files Created/Modified

- `server/priv/repo/migrations/20260101000004_create_inventory.exs` - Converted def change to def up/def down; partial unique index on shopping_list_items now uses raw SQL execute with WHERE purchased = 0
- `server/priv/repo/migrations/20260101000017_create_user_preferences.exs` - Replaced :jsonb with {:array, :map} for dashboard_widgets and :map for settings; fixed default values to Elixir types

## Decisions Made

- Used raw `execute` SQL for the partial index instead of attempting any Ecto DSL workaround — Ecto's `where:` option for `unique_index` is PostgreSQL-specific and not supported by ecto_sqlite3
- The `def down` function drops the manually-created index first (via `DROP INDEX IF EXISTS`) before dropping tables, because Ecto has no knowledge of the raw SQL index
- Default values changed from `"[]"` / `"{}"` strings to `[]` / `%{}` Elixir values — ecto_sqlite3 performs its own JSON serialization; string defaults bypass this and store the literal string characters

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Migration 04 and 17 are now fully SQLite-compatible
- Plan 02 (migration 13 — PL/pgSQL trigger rewrite) can proceed independently without interference from these files
- Two of the three targeted PostgreSQL-isms in migration files are resolved; migration 13 remains as the complex case

---
*Phase: 02-migration-rewrites*
*Completed: 2026-03-08*

## Self-Check: PASSED

- FOUND: server/priv/repo/migrations/20260101000004_create_inventory.exs
- FOUND: server/priv/repo/migrations/20260101000017_create_user_preferences.exs
- FOUND: .planning/phases/02-migration-rewrites/02-01-SUMMARY.md
- FOUND: commit 09646a8 (Task 1)
- FOUND: commit f40236e (Task 2)
