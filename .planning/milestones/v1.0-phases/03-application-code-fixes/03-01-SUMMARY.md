---
phase: 03-application-code-fixes
plan: "01"
subsystem: database
tags: [ecto, sqlite, ecto_sqlite3, elixir, testing, exunit]

# Dependency graph
requires:
  - phase: 02-migration-rewrites
    provides: SQLite-compatible migrations; ecto_sqlite3 adapter active
provides:
  - All search code paths unblocked (ilike -> like, 31 replacements across 5 modules)
  - MegaPlanner.DataCase CaseTemplate for DB-sandbox test setup
  - MegaPlanner.AccountsFixtures factory functions (user_fixture/0, household_fixture/0)
  - DB-safe test configuration (async: false on sandbox-using test files)
affects:
  - 03-02 (further application code fixes build on same codebase)
  - mix test compilation and runtime

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Use like/2 instead of ilike/2 for all Ecto case-insensitive string searches on ecto_sqlite3"
    - "DataCase CaseTemplate with Sandbox.start_owner!/stop_owner for test DB isolation"
    - "AccountsFixtures factory with System.unique_integer() for collision-free test data"

key-files:
  created:
    - server/test/support/data_case.ex
    - server/test/support/fixtures/accounts_fixtures.ex
  modified:
    - server/lib/mega_planner/search.ex
    - server/lib/mega_planner/receipts.ex
    - server/lib/mega_planner/goals.ex
    - server/lib/mega_planner/inventory.ex
    - server/lib/mega_planner/templates.ex
    - server/test/mega_planner/receipt_parsing_test.exs
    - server/test/mega_planner/habit_inventory_test.exs

key-decisions:
  - "like/2 used in place of ilike/2 everywhere: ecto_sqlite3 sets case_sensitive_like=OFF by default, making SQLite LIKE case-insensitive for ASCII equivalently to PostgreSQL ILIKE"
  - "DataCase does NOT set async: — defaults to false for all tests using it; async tests cannot share DB sandbox without race conditions"
  - "AccountsFixtures uses System.unique_integer() for emails and provider_ids to prevent unique constraint collisions across concurrent test runs"

patterns-established:
  - "ilike forbidden: all case-insensitive Ecto queries use like/2 on this SQLite backend"
  - "DB test files use async: false when calling Ecto.Adapters.SQL.Sandbox"

requirements-completed: [CODE-01, CODE-02]

# Metrics
duration: 3min
completed: 2026-03-07
---

# Phase 03 Plan 01: ilike-to-like Replacement and Test Infrastructure Summary

**Replaced 31 ilike/2 Ecto calls with like/2 across 5 context modules and created DataCase + AccountsFixtures test infrastructure to unblock all search code paths and fix compilation of DB-sandbox tests**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-07T07:15:45Z
- **Completed:** 2026-03-07T07:18:56Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- All 31 `ilike(` occurrences replaced with `like(` in search.ex (10), receipts.ex (13), goals.ex (3), inventory.ex (4), and templates.ex (1) — every search code path now executes without `Ecto.QueryError` on ecto_sqlite3
- Created `test/support/data_case.ex` with `MegaPlanner.DataCase` CaseTemplate using SQL Sandbox `start_owner!`/`stop_owner` lifecycle, referenced by bug_repro_test files
- Created `test/support/fixtures/accounts_fixtures.ex` with `user_fixture/0` and `household_fixture/0` factories using `System.unique_integer()` for collision-free test data
- Fixed `async: true` → `async: false` in receipt_parsing_test.exs and habit_inventory_test.exs to prevent sandbox race conditions

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace ilike with like in five context modules** - `b557abf` (fix)
2. **Task 2: Create test support infrastructure and fix async: false** - `6d88e29` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `server/lib/mega_planner/search.ex` - 10 ilike -> like replacements (tasks, inventory, budget, notes, goals, habits search)
- `server/lib/mega_planner/receipts.ex` - 13 ilike -> like replacements (brands, purchases, stores, store codes, item names)
- `server/lib/mega_planner/goals.ex` - 3 ilike -> like replacements (suggest_titles, suggest_milestone_titles)
- `server/lib/mega_planner/inventory.ex` - 4 ilike -> like replacements (create_item_from_purchase, find_matching_items)
- `server/lib/mega_planner/templates.ex` - 1 ilike -> like replacement (suggest_templates)
- `server/test/support/data_case.ex` - New: MegaPlanner.DataCase CaseTemplate with SQL sandbox setup
- `server/test/support/fixtures/accounts_fixtures.ex` - New: user_fixture/0 and household_fixture/0 factories
- `server/test/mega_planner/receipt_parsing_test.exs` - async: true -> async: false
- `server/test/mega_planner/habit_inventory_test.exs` - async: true -> async: false

## Decisions Made

- `like/2` replaces `ilike/2` everywhere: ecto_sqlite3 sets `case_sensitive_like: :off` (SQLite PRAGMA) by default, making `LIKE` case-insensitive for ASCII strings — equivalent to PostgreSQL `ILIKE`. No behavior change.
- `DataCase` does not set `async:` on the `use ExUnit.CaseTemplate` call — tests default to sync (async: false) which is required for DB sandbox correctness.
- `System.unique_integer()` used in factory functions for email and provider_id fields to prevent unique constraint violations when tests run in quick succession.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all replacements were straightforward token substitutions. Two unused alias warnings in accounts_fixtures.ex (`Repo` and `Household`) are from the plan's spec verbatim; they are harmless compile warnings, not errors.

## User Setup Required

None - no external service configuration required.

## Self-Check: PASSED

- `server/test/support/data_case.ex` - FOUND
- `server/test/support/fixtures/accounts_fixtures.ex` - FOUND
- `b557abf` (Task 1 commit) - FOUND
- `6d88e29` (Task 2 commit) - FOUND
- `grep -rn "ilike" server/lib/ | wc -l` = 0
- `grep -rn "async: true" server/test/ | wc -l` = 0
- `mix compile` - SUCCESS

## Next Phase Readiness

- All 31 ilike errors eliminated; search code paths unblocked for runtime use
- Test infrastructure ready: DataCase and AccountsFixtures available for any test that needs DB sandbox or fixture factories
- `mix test` should now reach runtime stage without compile errors about missing DataCase/AccountsFixtures modules
- Phase 03-02 can proceed on application code fixes (FK constraints, JSONB audit, async sandbox)

---
*Phase: 03-application-code-fixes*
*Completed: 2026-03-07*
