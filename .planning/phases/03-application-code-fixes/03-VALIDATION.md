---
phase: 3
slug: application-code-fixes
status: approved 2026-03-08
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-07
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `server/test/test_helper.exs` — sandbox already set to `:manual` mode |
| **Quick run command** | `grep -rn "ilike\|foreign_key_constraint" server/lib/ | wc -l` (returns 0 = clean) |
| **Full suite command** | `cd server && mix test` |
| **Estimated runtime** | ~15–30 seconds (migrations + test run) |

---

## Sampling Rate

- **After every task commit:** `grep -rn "ilike\|foreign_key_constraint" server/lib/ | wc -l` (should return 0)
- **After every plan wave:** `cd server && mix compile` (must exit 0)
- **After Wave 1 (Plans 01–03):** `cd server && mix test` (no adapter-incompatibility errors)
- **Before `/gsd:verify-work`:** Full suite green, human checkpoint in 03-04 approved
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-T1 | 01 | 1 | CODE-01 | smoke (grep) | `grep -rn "ilike" server/lib/ | wc -l` (→ 0) | ✅ shell | ⬜ pending |
| 03-01-T2 | 01 | 1 | CODE-02 | smoke (grep) | `grep -rn "async: true" server/test/ | wc -l` (→ 0) | ✅ shell | ⬜ pending |
| 03-02-T1 | 02 | 1 | CODE-03 | smoke (grep) | `grep -rn "foreign_key_constraint" server/lib/mega_planner/receipts/ | wc -l` (→ 0) | ✅ shell | ⬜ pending |
| 03-02-T2 | 02 | 1 | CODE-03 | smoke (grep) | `grep -rn "foreign_key_constraint" server/lib/mega_planner/calendar/ server/lib/mega_planner/goals/ | wc -l` (→ 0) | ✅ shell | ⬜ pending |
| 03-03-T1 | 03 | 1 | CODE-03 | smoke (grep) | `grep -rn "foreign_key_constraint" server/lib/mega_planner/inventory/ server/lib/mega_planner/accounts/ | wc -l` (→ 0) | ✅ shell | ⬜ pending |
| 03-03-T2 | 03 | 1 | CODE-03 | smoke (grep) | `grep -rn "foreign_key_constraint" server/lib/ | wc -l` (→ 0) | ✅ shell | ⬜ pending |
| 03-04-T1 | 04 | 2 | CODE-04 | smoke (grep) | `grep -rn "fragment" server/lib/ | grep -E '"->>|"->|@>|"\?' | wc -l` (→ 0) | ✅ shell | ⬜ pending |
| 03-04-T2 | 04 | 2 | CODE-01,02,03 | integration | `cd server && mix test 2>&1 | tail -5` | ✅ (mix test) | ⬜ pending |
| 03-04-T3 | 04 | 2 | all | checkpoint | human review | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Wave 0 gaps are resolved within Plan 03-01 (Task 2) before the full test suite runs:

- [x] `server/test/support/data_case.ex` — created in 03-01-T2; required by bug_repro_test.exs and bug_repro_trip_merge_test.exs
- [x] `server/test/support/fixtures/accounts_fixtures.ex` — created in 03-01-T2; required by bug_repro tests

Verify Wave 0 complete before running `mix test`:
```
ls server/test/support/data_case.ex server/test/support/fixtures/accounts_fixtures.ex
```

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Test results contain no SQLite adapter errors | CODE-01, CODE-02, CODE-03 | Requires reading test output for specific error patterns | Review `mix test` output in 03-04-T3 checkpoint for Ecto.QueryError (ilike), DataCase missing, ConstraintError, async concurrency errors |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (DataCase, AccountsFixtures created in 03-01)
- [x] No watch-mode flags in any verify command
- [x] Feedback latency < 30s (all verifications are grep or mix compile)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-08
