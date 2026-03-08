---
phase: 04-data-migration-pipeline
plan: "02"
subsystem: database
tags: [elixir, mix-tasks, sqlite, postgresql, postgrex, ecto, data-migration]

# Dependency graph
requires:
  - phase: 04-data-migration-pipeline plan 01
    provides: postgrex dev dep in mix.exs; migrate.export Mix task; JSON export file structure with top-level "tables" key

provides:
  - Mix.Tasks.Migrate.Import — reads migration_export.json and bulk-inserts into SQLite with PRAGMA FK handling and two-pass circular/self-ref FK resolution
  - Mix.Tasks.Migrate.Verify — connects to both PostgreSQL and SQLite, compares COUNT(*) per table, exits 1 on discrepancies

affects: [04-data-migration-pipeline plan 03 DATA-04, 04-data-migration-pipeline plan 04 DATA-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PRAGMA foreign_keys = OFF inside Repo.transaction/2 callback guarantees same-connection execution"
    - "Two-pass insert+update for self-referential FKs (tasks.parent_task_id, goal_categories.parent_id)"
    - "Two-pass for circular optional FKs (purchases.budget_entry_id <-> budget_entries.purchase_id)"
    - "~s[...] bracket sigil avoids Elixir parser conflicts with ~s(...) inside try/rescue blocks"
    - "sqlite_master query to get dynamic table list for verify task (excludes schema_migrations)"

key-files:
  created:
    - server/lib/mix/tasks/migrate.import.ex
    - server/lib/mix/tasks/migrate.verify.ex
  modified: []

key-decisions:
  - "PRAGMA foreign_keys = OFF placed inside Repo.transaction callback — not before it — to guarantee same-connection scoping (ecto_sqlite3 can check out different connections from pool)"
  - "~s[...] bracket delimiter used for SQL interpolation inside try/rescue blocks to avoid Elixir MismatchedDelimiterError with ~s(...) paren sigil"
  - "import_table/2 has nil-guard clause for tables missing from export — prevents crash on partial exports"
  - "Two-pass functions have nil-guard clauses for graceful skip when export section is absent"

patterns-established:
  - "Two-pass pattern: insert with FK column set to nil, then UPDATE where original value was non-nil"
  - "PRAGMA foreign_key_check after import: zero rows = pass, non-zero rows = print violations + raise"
  - "Verify task uses try/rescue per table to handle table-not-in-one-DB edge case without crash"

requirements-completed: [DATA-02, DATA-03]

# Metrics
duration: 4min
completed: 2026-03-08
---

# Phase 4 Plan 02: Import and Verify Mix Tasks Summary

**mix migrate.import with two-pass FK handling for three circular/self-referential cases + mix migrate.verify comparing PostgreSQL vs SQLite COUNT(*) per table**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-08T04:28:14Z
- **Completed:** 2026-03-08T04:31:51Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `mix migrate.import` reads any JSON export from 04-01 and bulk-inserts 48 tables into SQLite with PRAGMA FK enforcement disabled for the duration
- Three two-pass import functions handle tasks (parent_task_id), goal_categories (parent_id), and purchases+budget_entries (circular optional FK) — PRAGMA foreign_key_check verifies zero violations after import
- `mix migrate.verify` dynamically discovers tables from sqlite_master, queries COUNT(*) from both PostgreSQL (via Postgrex) and SQLite (via Repo), and reports MISMATCH/OK per table with exit code 1 on any discrepancy

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement migrate.import Mix task** - `7ce7775` (feat)
2. **Task 2: Implement migrate.verify Mix task** - `4328ad8` (feat)

**Plan metadata:** (docs commit pending)

## Files Created/Modified
- `server/lib/mix/tasks/migrate.import.ex` — Full import implementation: 44 standard tables via import_table/2, three two-pass helpers for circular/self-referential FKs, PRAGMA foreign_key_check exit gate
- `server/lib/mix/tasks/migrate.verify.ex` — Count comparison: dynamic table discovery from sqlite_master, Postgrex + Repo parallel counts, try/rescue per table, exit {:shutdown, 1} on discrepancies

## Decisions Made
- PRAGMA foreign_keys = OFF is placed inside the `Repo.transaction/2` callback (`fn -> ... end`), not before it. The ecto_sqlite3 adapter defaults to `foreign_keys: :on` on each connection checkout — placing the PRAGMA inside the transaction guarantees same-connection execution
- Used `~s[...]` (bracket sigil) instead of `~s(...)` (paren sigil) for SQL interpolation inside try/rescue blocks. Elixir's parser treats the closing `)` of `~s(SELECT COUNT(*) FROM "...")` as a match for the `try do` opening delimiter, causing MismatchedDelimiterError at compile time
- `import_table/2` has an explicit `nil` clause: if a table key is missing from the export JSON, it prints a warning and skips rather than crashing

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed ~s() sigil compile error in migrate.verify.ex**
- **Found during:** Task 2 (migrate.verify implementation)
- **Issue:** `~s(SELECT COUNT(*) FROM "#{table}")` inside `try do` block caused `MismatchedDelimiterError` — Elixir parser matched the sigil's closing `)` to the `try do` opening delimiter
- **Fix:** Changed all SQL sigils from `~s(...)` to `~s[...]` bracket form which does not conflict with Elixir's delimiter matching
- **Files modified:** server/lib/mix/tasks/migrate.verify.ex
- **Verification:** `mix compile --force` succeeded with zero errors after fix
- **Committed in:** `4328ad8` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Fix was necessary for compilation. No scope creep.

## Issues Encountered
- Pre-existing test failures (26 tests, 26 failures) in the test suite related to `MegaPlanner.Accounts.create_household/1` being undefined/private. Confirmed these existed before this plan's changes — no new failures introduced.

## User Setup Required
None - no external service configuration required for this plan. POSTGRES_URL is required only at runtime when actually running the verify task against production.

## Next Phase Readiness
- Both import and verify tasks compile and are ready for functional testing
- DATA-04 (production export via fly proxy) and DATA-05 (import + verify against production data) can now proceed
- Full functional test requires a real export file from `mix migrate.export` (implemented in 04-01)

## Self-Check: PASSED

- FOUND: server/lib/mix/tasks/migrate.import.ex
- FOUND: server/lib/mix/tasks/migrate.verify.ex
- FOUND: .planning/phases/04-data-migration-pipeline/04-02-SUMMARY.md
- FOUND commit: 7ce7775 (migrate.import)
- FOUND commit: 4328ad8 (migrate.verify)
- FOUND commit: e895a8e (docs metadata)

---
*Phase: 04-data-migration-pipeline*
*Completed: 2026-03-08*
