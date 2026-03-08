---
phase: 2
slug: migration-rewrites
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-07
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in) + `mix ecto.migrate` |
| **Config file** | `server/test/test_helper.exs` (exists) |
| **Quick run command** | `cd server && mix compile --warnings-as-errors` |
| **Full suite command** | `cd server && mix ecto.reset` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd server && mix compile --warnings-as-errors`
- **After every plan wave:** Run `cd server && mix ecto.migrate`
- **Before `/gsd:verify-work`:** Full suite (`mix ecto.reset`) must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 1 | MIGR-01 | smoke | `cd server && mix ecto.migrate 2>&1 \| grep -E "error\|Error\|migrated"` | ✅ | ⬜ pending |
| 2-01-02 | 01 | 1 | MIGR-02 | smoke | `cd server && grep -rn ":jsonb" priv/repo/migrations/` | ✅ | ⬜ pending |
| 2-01-03 | 01 | 1 | MIGR-03 | smoke | `cd server && grep -rn "purchased = false" priv/repo/migrations/` | ✅ | ⬜ pending |
| 2-01-04 | 01 | 1 | MIGR-04 | integration | `cd server && mix ecto.reset` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. Phase 2 verification is migration-runner and grep based, not ExUnit test based.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| All ~60 migrations run from scratch | MIGR-04 | Integration test requires clean SQLite DB state | Run `cd server && mix ecto.reset` and confirm no errors in output |
| Partial index uses `WHERE purchased = 0` | MIGR-03 | Requires reading migration SQL output | Inspect migration 04 file after edit; confirm no `purchased = false` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
