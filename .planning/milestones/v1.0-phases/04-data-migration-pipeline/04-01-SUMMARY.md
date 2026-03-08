---
phase: 04-data-migration-pipeline
plan: "01"
subsystem: database
tags: [postgrex, elixir, mix-task, postgresql, export, json, migration]

# Dependency graph
requires:
  - phase: 03-application-code-fixes
    provides: "Fully working Elixir/Phoenix app targeting SQLite, all code fixes applied"
provides:
  - "mix migrate.export task — exports all 48 PostgreSQL tables to structured JSON"
  - "postgrex 0.21 dev/test dependency for direct PostgreSQL access"
  - "server/lib/mix/tasks/ directory with export module"
affects: [04-02-import, 04-03-verify, 04-04-cutover]

# Tech tracking
tech-stack:
  added: [postgrex ~> 0.21 (dev/test only)]
  patterns:
    - "Mix task modules under lib/mix/tasks/ with defmodule Mix.Tasks.Namespace.Action"
    - "Postgrex.start_link via Ecto.Repo.Supervisor.parse_url for direct DB access without Ecto overhead"
    - "serialize/1 multi-clause pattern for JSON-safe type coercion (NaiveDateTime, DateTime, Decimal)"
    - "POSTGRES_URL env var pattern for production DB access (with fly proxy tunnel)"

key-files:
  created:
    - server/lib/mix/tasks/migrate.export.ex
  modified:
    - server/mix.exs

key-decisions:
  - "postgrex added as only: [:dev, :test] (not :prod) — not needed at runtime, only for one-time migration"
  - "@tables module attribute with ~w[] sigil listing all 48 data tables ensures compile-time safety"
  - "serialize/1 pass-through clause (defp serialize(v), do: v) handles nil, string, integer, float, boolean without explicit clauses"
  - "pool_size: 2 and timeout: 60_000 set for export stability under large table loads"

patterns-established:
  - "Export JSON structure: {exported_at: ISO8601, tables: {table_name: [row_map, ...]}}"
  - "row_to_map/2 pattern: Enum.zip(columns, row) |> Map.new() for Postgrex result conversion"
  - "Application.ensure_all_started(:mega_planner) at top of Mix task run/1 to boot app context"

requirements-completed: [DATA-01]

# Metrics
duration: 6min
completed: 2026-03-08
---

# Phase 4 Plan 01: Export Task Summary

**Postgrex-powered mix migrate.export Mix task that exports all 48 PostgreSQL tables to a structured JSON file with NaiveDateTime/DateTime/Decimal type coercion**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-08T04:28:08Z
- **Completed:** 2026-03-08T04:34:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `{:postgrex, "~> 0.21", only: [:dev, :test]}` dep to server/mix.exs; `mix deps.get && mix compile` succeed with postgrex 0.21.1
- Created `server/lib/mix/tasks/migrate.export.ex` — 114 lines, `Mix.Tasks.Migrate.Export` module with 48-table `@tables` attribute, full `run/1` implementation, `row_to_map/2`, and 6 `serialize/1` clauses
- mix compile --force (103 files) exits with zero errors or warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Add postgrex dev dep and create Mix tasks directory** - `eecdb9d` (chore)
2. **Task 2: Implement migrate.export Mix task** - `444bc76` (feat)

## Files Created/Modified

- `server/mix.exs` - Added `{:postgrex, "~> 0.21", only: [:dev, :test]}` in Dev/Test deps section
- `server/lib/mix/tasks/migrate.export.ex` - Full Mix.Tasks.Migrate.Export implementation

## Decisions Made

- Used `only: [:dev, :test]` instead of `only: :dev` per plan guidance — test env may need postgrex if future tests validate export; avoids compile errors in test environment
- `pool_size: 2` and `timeout: 60_000` set on Postgrex connection opts for stability with large tables
- `Application.ensure_all_started(:mega_planner)` called first in `run/1` to ensure Repo and config are available

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — `mix compile --force` (103 files) succeeded with zero errors on first attempt.

## User Setup Required

None - no external service configuration required for this task. The task itself requires `POSTGRES_URL` at runtime, but no setup is needed to build/compile the code.

## Next Phase Readiness

- `mix migrate.export <path>` task is ready for execution once `fly proxy 5432:5432 -a mega-planner-api-db` is running and `POSTGRES_URL` is set
- Plan 04-02 (migrate.import) is already committed (`7ce7775`) — import task is ready to consume the export file
- Plan 04-03 (migrate.verify) file exists as untracked in the same directory

---
*Phase: 04-data-migration-pipeline*
*Completed: 2026-03-08*

## Self-Check: PASSED

- FOUND: server/lib/mix/tasks/migrate.export.ex
- FOUND: server/mix.exs (with postgrex dep)
- FOUND: .planning/phases/04-data-migration-pipeline/04-01-SUMMARY.md
- FOUND commit: eecdb9d (Task 1)
- FOUND commit: 444bc76 (Task 2)
