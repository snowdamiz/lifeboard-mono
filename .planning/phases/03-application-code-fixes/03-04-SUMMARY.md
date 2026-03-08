---
phase: 03-application-code-fixes
plan: "04"
subsystem: database
tags: [ecto, sqlite, ecto_sqlite3, elixir, testing, exunit, migrations]

# Dependency graph
requires:
  - phase: 03-application-code-fixes
    provides: "CODE-01 ilike->like, CODE-02 DataCase/async:false, CODE-03 FK constraints -> validate_change/3 (plans 01-03)"
provides:
  - "CODE-04 verified: zero JSONB operators in lib/ fragment strings"
  - "Integration gate confirmed: mix test runs without any adapter-incompatibility failures"
  - "Migration 20260101000018 corrected: household_id preserved through SQLite table-rebuild"
affects: [04-data-export, 05-deploy]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SQLite table-rebuild migrations must explicitly list ALL existing columns in CREATE TABLE (no implicit column inheritance)"

key-files:
  created: []
  modified:
    - server/priv/repo/migrations/20260101000018_create_shopping_lists.exs

key-decisions:
  - "Migration 20260101000018 table-rebuild bug identified and fixed: the shopping_list_items_new CREATE TABLE omitted household_id (added by migration 13), causing no-such-column failures at runtime; fix adds household_id to both up and down DDL"
  - "Pre-existing application bugs (Accounts.create_household/1 undefined, Decimal vs integer type assertion) are NOT adapter issues; they are left unfixed as out-of-scope per plan intent"

patterns-established:
  - "SQLite table-rebuild pattern: every column present at migration run time (including those from prior migrations) must be explicitly listed in CREATE TABLE and the INSERT SELECT"

requirements-completed: [CODE-04]

# Metrics
duration: 5min
completed: 2026-03-08
---

# Phase 03 Plan 04: Integration Gate — CODE-04 Verification and Full Test Suite Summary

**Verified zero JSONB/ilike/FK-constraint in lib/, fixed household_id table-rebuild bug in migration 18, and confirmed mix test runs clean of all four adapter-incompatibility error patterns**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-08T03:33:11Z
- **Completed:** 2026-03-08T03:38:00Z
- **Tasks:** 2 of 3 (Task 3 is human checkpoint)
- **Files modified:** 2

## Accomplishments

- All three grep verifications pass: zero ilike, zero foreign_key_constraint, zero JSONB operators in lib/
- Discovered and fixed migration bug: migration 20260101000018 (create_shopping_lists) rebuilt shopping_list_items table without household_id column added by migration 20260101000013, causing Exqlite.Error no-such-column failures
- mix test runs clean: none of the four forbidden error patterns appear (no ilike Ecto.QueryError, no DataCase missing, no Ecto.ConstraintError, no DBConnection async errors)
- 26 total test failures are pre-existing application bugs (Accounts.create_household/1 undefined, Decimal/integer type assertion) and one intentional bug-repro test

## Task Commits

Each task was committed atomically:

1. **Task 1: Verify CODE-04 — zero JSONB operators, ilike, foreign_key_constraint in lib/** - `745cd3f` (chore)
2. **Task 2: Run full test suite + fix migration household_id table-rebuild bug** - `b2aaa25` (fix)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `server/priv/repo/migrations/20260101000018_create_shopping_lists.exs` - Added household_id to the shopping_list_items_new CREATE TABLE DDL and INSERT SELECT in both up and down directions

## Decisions Made

- Migration 20260101000018 rebuilds shopping_list_items using the SQLite table-rebuild pattern. The original CREATE TABLE omitted household_id (added earlier by migration 20260101000013), silently dropping the column. The fix adds `household_id BLOB REFERENCES households(id) ON DELETE CASCADE` to the DDL and includes it in the INSERT SELECT. Both up and down directions are fixed for consistency.
- Remaining 26 test failures are pre-existing application bugs (not adapter-incompatibility errors) and are intentionally left unfixed — fixing them would require implementing Accounts.create_household/1 which is out of scope for Phase 3.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored household_id in shopping_list_items SQLite table-rebuild migration**
- **Found during:** Task 2 (Run full test suite)
- **Issue:** Migration 20260101000018 (create_shopping_lists) uses SQLite table-rebuild pattern to add shopping_list_id and name columns to shopping_list_items. The CREATE TABLE for the rebuilt table omitted household_id (which was added by migration 20260101000013), causing SQLite to silently drop the column and resulting in `Exqlite.Error: no such column: s0.household_id` on any query that joins or selects shopping_list_items.
- **Fix:** Added `household_id BLOB REFERENCES households(id) ON DELETE CASCADE` to the `shopping_list_items_new` CREATE TABLE DDL in the `up` direction, and updated the INSERT SELECT to include household_id. Also updated the `down` direction's `shopping_list_items_orig` CREATE TABLE and INSERT SELECT for consistency.
- **Files modified:** server/priv/repo/migrations/20260101000018_create_shopping_lists.exs
- **Verification:** Fresh database drop/create/migrate cycle followed by mix test confirms Exqlite.Error no-such-column is eliminated; sqlite3 PRAGMA table_info(shopping_list_items) shows household_id at position 5
- **Committed in:** `b2aaa25` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** The migration bug fix is necessary for the test suite to correctly exercise the shopping_list_items table. No scope creep — the fix directly enables the Task 2 verification requirement.

## Issues Encountered

- SQLite table-rebuild migration (20260101000018) omitted a column from migration 20260101000013. This is a known risk of the SQLite table-rebuild pattern: all existing columns must be explicitly listed. Fixed inline per Rule 1.

## User Setup Required

None - no external service configuration required.

## Phase 3 Integration Gate Status

All four CODE requirements satisfied as verified:

| Requirement | grep verification | Status |
|-------------|-------------------|--------|
| CODE-01: zero ilike in lib/ | `grep -rn "ilike" server/lib/ \| wc -l` = 0 | PASS |
| CODE-02: DataCase exists, async:false on DB tests | Files exist, grep confirms 0 async:true | PASS |
| CODE-03: zero foreign_key_constraint in lib/ | `grep -rn "foreign_key_constraint" server/lib/ \| wc -l` = 0 | PASS |
| CODE-04: zero JSONB operators in fragment strings | grep returns 0 lines | PASS |

**mix test adapter compatibility check:**
- ilike Ecto.QueryError: NOT PRESENT
- DataCase is not loaded: NOT PRESENT
- Ecto.ConstraintError on insert: NOT PRESENT
- DBConnection async concurrency errors: NOT PRESENT

**AWAITING CHECKPOINT:** Human verification of results above before marking Phase 3 complete.

## Next Phase Readiness

- Phase 3 CODE fixes verified complete pending human checkpoint approval
- Migration bug fix ensures test database schema matches the Elixir schema module definitions
- Ready for Phase 4 (data export) once checkpoint approved

---
*Phase: 03-application-code-fixes*
*Completed: 2026-03-08*
