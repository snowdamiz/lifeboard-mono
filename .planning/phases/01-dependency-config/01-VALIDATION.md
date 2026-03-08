---
phase: 1
slug: dependency-config
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-07
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in Elixir) |
| **Config file** | `server/test/test_helper.exs` (exists) |
| **Quick run command** | `cd server && mix compile` |
| **Full suite command** | `cd server && mix compile --warnings-as-errors && mix deps \| grep -E "ecto_sqlite3\|postgrex\|ecto_sql"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd server && mix compile`
- **After every plan wave:** Run `cd server && mix compile --warnings-as-errors && mix deps | grep -E "ecto_sqlite3|postgrex|ecto_sql"`
- **Before `/gsd:verify-work`:** Full suite must be green (compile + dep check + `mix ecto.create` creates `server/mega_planner_dev.db`)
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | DEPS-01, DEPS-02 | smoke | `cd server && mix deps \| grep -E "ecto_sqlite3\|postgrex\|ecto_sql"` | ✅ | ⬜ pending |
| 1-01-02 | 01 | 1 | DEPS-01, DEPS-02 | smoke | `cd server && mix compile` | ✅ | ⬜ pending |
| 1-01-03 | 01 | 1 | DEPS-03 | smoke | `grep -rn "SQLite3\|postgres" server/config/dev.exs` | ✅ | ⬜ pending |
| 1-01-04 | 01 | 1 | DEPS-04 | smoke | `grep -rn "DATABASE_PATH\|DATABASE_URL" server/config/runtime.exs` | ✅ | ⬜ pending |
| 1-01-05 | 01 | 1 | DEPS-05 | smoke | `grep -rn "SQLite3\|postgres" server/config/test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

Phase 1 verification is compile-time and grep-based, not runtime test-based. No new test files are needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `mix ecto.create` creates `server/mega_planner_dev.db` | DEPS-03 | Requires running Mix task with side effects | `cd server && mix ecto.create && ls -la mega_planner_dev.db` |
| Adapter module confirmed via IEx | DEPS-01 | Compile-level runtime verification | `cd server && mix run --no-start -e "IO.inspect(MegaPlanner.Repo.__adapter__())"` — expect `Ecto.Adapters.SQLite3` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
