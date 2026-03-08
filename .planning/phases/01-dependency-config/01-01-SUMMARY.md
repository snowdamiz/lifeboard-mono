---
phase: 01-dependency-config
plan: 01
subsystem: database
tags: [elixir, ecto, sqlite3, ecto_sqlite3, exqlite, mix]

# Dependency graph
requires: []
provides:
  - ecto_sqlite3 0.22.0 locked as the Ecto adapter (no postgrex)
  - MegaPlanner.Repo configured with Ecto.Adapters.SQLite3
  - migration_primary_key: binary_id (UUID) set for all future migrations
  - migration_timestamps: utc_datetime set for all future migrations
affects:
  - 01-02 (database file path config and environment-specific settings depend on this adapter)
  - 02 (schema and migration phase depends on adapter and migration_primary_key)
  - 03 (testing phase depends on SQLite3 adapter being in place)

# Tech tracking
tech-stack:
  added:
    - ecto_sqlite3 0.22.0 (Elixir SQLite adapter replacing Ecto.Adapters.Postgres)
    - exqlite 0.35.0 (transitive NIF-based SQLite3 driver)
    - cc_precompiler 0.1.11 (transitive, used for precompiled NIFs)
    - elixir_make 0.9.0 (transitive, used for NIF compilation)
  patterns:
    - ecto_sql constraint pinned to ~> 3.13 (matches ecto_sqlite3 0.22 requirement)
    - Repo adapter declared in repo.ex use macro, not in config files
    - migration_primary_key set at repo config level so every migration inherits binary_id

key-files:
  created: []
  modified:
    - server/mix.exs
    - server/mix.lock
    - server/lib/mega_planner/repo.ex
    - server/config/config.exs

key-decisions:
  - "ecto_sqlite3 ~> 0.22 selected as mandated adapter — most actively maintained SQLite Ecto adapter"
  - "postgrex removed entirely rather than kept as optional dep to prevent compile-time Postgres references"
  - "migration_primary_key: [name: :id, type: :binary_id] set at repo config level, not per-migration"

patterns-established:
  - "Adapter declaration: use Ecto.Repo, adapter: Ecto.Adapters.SQLite3 (not in config)"
  - "UUID primary keys via migration_primary_key binary_id — all tables inherit this automatically"

requirements-completed: [DEPS-01, DEPS-02]

# Metrics
duration: 3min
completed: 2026-03-08
---

# Phase 1 Plan 01: Dependency & Adapter Swap Summary

**Replaced postgrex with ecto_sqlite3 0.22.0, updated MegaPlanner.Repo to Ecto.Adapters.SQLite3, and configured UUID binary_id primary keys for all future migrations**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-08T01:51:45Z
- **Completed:** 2026-03-08T01:54:48Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Removed `{:postgrex, ">= 0.0.0"}` and added `{:ecto_sqlite3, "~> 0.22"}` to mix.exs; ecto_sql bumped to `~> 3.13`
- Changed `MegaPlanner.Repo` adapter from `Ecto.Adapters.Postgres` to `Ecto.Adapters.SQLite3`
- Added `config :mega_planner, MegaPlanner.Repo` block with `migration_primary_key: [name: :id, type: :binary_id]` and `migration_timestamps: [type: :utc_datetime]`
- `mix compile --force` and `mix compile --warnings-as-errors` both exit 0; `Repo.__adapter__()` returns `Ecto.Adapters.SQLite3`

## Task Commits

Each task was committed atomically:

1. **Task 1: Swap postgrex for ecto_sqlite3 in mix.exs and install deps** - `5e76b0b` (feat)
2. **Task 2: Change Repo adapter and add migration_primary_key config** - `659c372` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `server/mix.exs` - ecto_sql ~> 3.13, ecto_sqlite3 ~> 0.22 added; postgrex removed
- `server/mix.lock` - ecto_sqlite3 0.22.0, exqlite 0.35.0, cc_precompiler, elixir_make locked
- `server/lib/mega_planner/repo.ex` - adapter changed to Ecto.Adapters.SQLite3
- `server/config/config.exs` - new `config :mega_planner, MegaPlanner.Repo` block with migration_primary_key and migration_timestamps

## Decisions Made
- Used `ecto_sqlite3 ~> 0.22` (not raw `exqlite`) as the mandated adapter for its higher-level Ecto integration
- Removed `postgrex` entirely (not kept as optional) to ensure no stale Postgres references survive `mix compile`
- Set `migration_primary_key: [name: :id, type: :binary_id]` at the repo config level so all generated migrations inherit UUID primary keys without per-migration boilerplate

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `mix deps.clean postgrex --build` printed a warning that postgrex was not present in the build directory. This is expected — postgrex was never compiled because it was removed before `mix compile` ran. No action was needed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- SQLite3 adapter is fully in place; `mix compile` is clean with no warnings in mega_planner app
- Plan 01-02 (environment-specific database file path config) can proceed immediately
- The `migration_primary_key` setting is ready for schema creation in Phase 2

---
*Phase: 01-dependency-config*
*Completed: 2026-03-08*
