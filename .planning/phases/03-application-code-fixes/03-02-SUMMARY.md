---
phase: 03-application-code-fixes
plan: "02"
subsystem: database
tags: [ecto, sqlite, changeset, validation, foreign-key]

# Dependency graph
requires:
  - phase: 02-migration-rewrites
    provides: SQLite-compatible migrations defining the tables these schemas reference
provides:
  - validate_change/3 pre-insert FK existence checks replacing foreign_key_constraint/3 across receipts, calendar, and goals domains
affects: [04-data-migration, testing]

# Tech tracking
tech-stack:
  added: []
  patterns: [validate_change/3 with Repo.get pre-insert existence check instead of foreign_key_constraint/3]

key-files:
  created: []
  modified:
    - server/lib/mega_planner/receipts/trip.ex
    - server/lib/mega_planner/receipts/stop.ex
    - server/lib/mega_planner/receipts/purchase.ex
    - server/lib/mega_planner/receipts/tax_indicator_meaning.ex
    - server/lib/mega_planner/receipts/store.ex
    - server/lib/mega_planner/receipts/driver.ex
    - server/lib/mega_planner/receipts/brand.ex
    - server/lib/mega_planner/receipts/format_correction.ex
    - server/lib/mega_planner/calendar/task_step.ex
    - server/lib/mega_planner/calendar/task.ex
    - server/lib/mega_planner/calendar/task_template.ex
    - server/lib/mega_planner/goals/habit.ex
    - server/lib/mega_planner/goals/goal_status_change.ex
    - server/lib/mega_planner/goals/goal.ex
    - server/lib/mega_planner/goals/habit_inventory.ex
    - server/lib/mega_planner/goals/goal_category.ex

key-decisions:
  - "validate_change/3 replaces foreign_key_constraint/3 everywhere: ecto_sqlite3 returns [foreign_key: nil] causing unhandled Ecto.ConstraintError (500) instead of changeset validation errors"
  - "validate_change/3 fires only when field is present and changed in cast — optional FK fields (driver_id, budget_entry_id, parent_task_id, goal_category_id, parent_id) correctly handled since nil is never passed to the validator"
  - "Self-referential FKs (parent_task_id -> Task, parent_id -> GoalCategory) use __MODULE__ as the Repo.get target"

patterns-established:
  - "FK existence check pattern: |> validate_change(:field_id, fn :field_id, id -> if Repo.get(Module, id), do: [], else: [field_id: \"does not exist\"] end)"

requirements-completed: [CODE-03]

# Metrics
duration: 7min
completed: 2026-03-07
---

# Phase 03 Plan 02: FK Constraint Replacement Summary

**27 foreign_key_constraint/3 calls replaced with validate_change/3 Repo.get pre-insert checks across 16 schema files in receipts, calendar, and goals domains**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-07T21:02:16Z
- **Completed:** 2026-03-07T21:09:20Z
- **Tasks:** 2
- **Files modified:** 16

## Accomplishments
- Replaced 14 FK constraints across 8 receipts schema files — trip, stop, purchase, tax_indicator_meaning, store, driver, brand, format_correction
- Replaced 13 FK constraints across 8 calendar and goals schema files — task_step, task, task_template, habit, goal_status_change, goal, habit_inventory, goal_category
- All 27 replacements compile cleanly with `mix compile` producing zero errors or warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace FK constraints in receipts schemas (8 files)** - `90baef7` (fix)
2. **Task 2: Replace FK constraints in calendar and goals schemas (8 files)** - `bef04fd` (fix)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `server/lib/mega_planner/receipts/trip.ex` - household_id, user_id, driver_id (3 FK checks)
- `server/lib/mega_planner/receipts/stop.ex` - trip_id, store_id (2 FK checks)
- `server/lib/mega_planner/receipts/purchase.ex` - household_id, stop_id, budget_entry_id (3 FK checks)
- `server/lib/mega_planner/receipts/tax_indicator_meaning.ex` - household_id (1 FK check)
- `server/lib/mega_planner/receipts/store.ex` - household_id (1 FK check)
- `server/lib/mega_planner/receipts/driver.ex` - household_id, user_id (2 FK checks)
- `server/lib/mega_planner/receipts/brand.ex` - household_id (1 FK check)
- `server/lib/mega_planner/receipts/format_correction.ex` - household_id (1 FK check)
- `server/lib/mega_planner/calendar/task_step.ex` - task_id (1 FK check)
- `server/lib/mega_planner/calendar/task.ex` - user_id, household_id, parent_task_id (3 FK checks, self-referential preserved via __MODULE__)
- `server/lib/mega_planner/calendar/task_template.ex` - household_id (1 FK check)
- `server/lib/mega_planner/goals/habit.ex` - household_id (1 FK check)
- `server/lib/mega_planner/goals/goal_status_change.ex` - goal_id, user_id (2 FK checks)
- `server/lib/mega_planner/goals/goal.ex` - household_id, goal_category_id (2 FK checks)
- `server/lib/mega_planner/goals/habit_inventory.ex` - household_id (1 FK check)
- `server/lib/mega_planner/goals/goal_category.ex` - household_id, parent_id (2 FK checks, self-referential preserved via __MODULE__)

## Decisions Made
- `validate_change/3` replaces `foreign_key_constraint/3` everywhere: ecto_sqlite3 returns `[foreign_key: nil]` causing an unhandled `Ecto.ConstraintError` (500 server error) instead of a graceful changeset validation error. The validate_change pattern does a Repo.get pre-insert check and adds a changeset error instead of crashing.
- `validate_change/3` only fires when the field is present and changed in the cast — optional FK fields (driver_id, budget_entry_id, parent_task_id, goal_category_id, parent_id) are correctly handled since nil values are never passed through to the validator.
- Self-referential FKs (`parent_task_id -> Task`, `parent_id -> GoalCategory`) use `__MODULE__` as the Repo.get target module, maintaining the same module reference pattern as the schema definition.

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All schema modules in receipts, calendar, and goals domains now produce proper changeset errors on invalid FK references instead of crashing with Ecto.ConstraintError
- Ready for Plan 03-03 (async sandbox and any remaining application code fixes)
- No blockers

## Self-Check: PASSED
- All 16 modified files verified present
- Commits 90baef7 (receipts) and bef04fd (calendar/goals) verified in git log
- `mix compile` exits 0 with no output (no errors, no warnings)
- `grep -rn "foreign_key_constraint" receipts/ | wc -l` = 0
- `grep -rn "foreign_key_constraint" calendar/ goals/ | wc -l` = 0

---
*Phase: 03-application-code-fixes*
*Completed: 2026-03-07*
