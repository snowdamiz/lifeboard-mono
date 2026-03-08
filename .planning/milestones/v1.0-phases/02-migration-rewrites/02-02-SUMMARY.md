---
phase: 02-migration-rewrites
plan: "02"
subsystem: database
tags: [ecto, sqlite, migration, uuid, elixir]

# Dependency graph
requires:
  - phase: 01-dependency-config
    provides: ecto_sqlite3 adapter wired up; per-env SQLite config in place
  - phase: 02-migration-rewrites/02-01
    provides: migration 12 adding users.household_id column
provides:
  - Migration 13 back-fill block rewritten in pure Elixir using execute fn -> and Ecto.UUID.generate()
affects: [02-migration-rewrites, 03-validation, phase-3-testing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "execute fn -> block for application-layer data migrations in Ecto (replaces PL/pgSQL DO $$ blocks)"
    - "repo().query/2 (no bang) for SELECT; repo().query!/2 (bang) for INSERT/UPDATE in migrations"
    - "? positional params for SQLite (not $1 PostgreSQL style)"
    - "Ecto.UUID.generate() for UUID generation in Elixir migration code"

key-files:
  created: []
  modified:
    - server/priv/repo/migrations/20260101000013_add_household_id_to_data_tables.exs

key-decisions:
  - "repo().query/2 used for SELECT (pattern-match on {:ok, %{rows: [...]}}); repo().query!/2 for mutations (raises on error)"
  - "Timestamp computed once before the loop via DateTime.utc_now |> truncate(:second) |> to_iso8601() — all rows get same timestamp, matching original NOW() behavior"
  - "user_id passed as-is from SELECT result (binary blob) to UPDATE positional param — no UUID conversion needed"
  - "Elixir || operator for COALESCE(name, email) — short-circuits on truthy name, falls back to email"

patterns-established:
  - "Migration data back-fill pattern: execute fn -> block with repo().query/2 SELECT then repo().query!/2 mutations"

requirements-completed:
  - MIGR-01

# Metrics
duration: 1min
completed: "2026-03-08"
---

# Phase 02 Plan 02: Migration 13 PL/pgSQL-to-Elixir Rewrite Summary

**Migration 13 household back-fill rewritten from PL/pgSQL DO $$ block to pure Elixir execute fn -> using repo().query!/2 and Ecto.UUID.generate() for SQLite compatibility**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-03-08T02:23:17Z
- **Completed:** 2026-03-08T02:24:15Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Removed the entire `execute """ DO $$ ... gen_random_uuid() ... END $$; """` block from migration 13
- Replaced with `execute fn ->` block that uses `repo().query/2` to SELECT users without a household and `repo().query!/2` to INSERT into households and UPDATE users
- Used `Ecto.UUID.generate()` for UUID generation in the application layer — no PostgreSQL functions required
- Used `?` positional params (SQLite/exqlite style) throughout
- `mix compile --warnings-as-errors` passes cleanly; `grep -rn "gen_random_uuid" priv/repo/migrations/` returns zero results

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace PL/pgSQL block with Elixir execute fn ->** - `75ac596` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified

- `server/priv/repo/migrations/20260101000013_add_household_id_to_data_tables.exs` - Replaced 15-line PL/pgSQL block with 24-line Elixir execute fn -> block; all other content unchanged

## Decisions Made

- `repo().query/2` (no bang) for SELECT: returns `{:ok, %{rows: [...]}}` which pattern-matches cleanly; safer than query! for reads
- `repo().query!/2` (with bang) for INSERT/UPDATE: raises on error, correct behavior for migration failures that must abort the migration
- Timestamp (`now`) computed once before `Enum.each` loop so all rows share the same timestamp — consistent with original `NOW()` semantics
- `user_id` passed through as-is from query result — the binary blob value is passed directly as a positional parameter without UUID encoding/decoding
- `name || email` uses Elixir's `||` operator (truthy short-circuit), which exactly mirrors PostgreSQL's `COALESCE(name, email)` behavior

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Migration 13 is now SQLite-compatible; no PL/pgSQL or PostgreSQL-specific functions remain in migration 13
- Migration 14 through the final migration still need review (covered by plans 03+)
- The `def down/0` function was untouched as specified — it only drops columns and indexes, no data migration needed on rollback

---
*Phase: 02-migration-rewrites*
*Completed: 2026-03-08*

## Self-Check: PASSED

- migration 13 file: FOUND
- SUMMARY.md: FOUND
- commit 75ac596: FOUND
