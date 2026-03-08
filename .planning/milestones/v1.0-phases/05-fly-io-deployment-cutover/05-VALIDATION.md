---
phase: 5
slug: fly-io-deployment-cutover
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-08
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in) + Fly CLI smoke tests |
| **Config file** | `server/test/test_helper.exs` |
| **Quick run command** | `cd server && mix test --no-start` |
| **Full suite command** | `cd server && mix test` |
| **Estimated runtime** | ~10 seconds (ExUnit) + manual smoke tests |

---

## Sampling Rate

- **After every task commit:** Run static file checks (grep commands per task)
- **After every plan wave:** Run `fly logs --app mega-planner-api` + smoke test
- **Before `/gsd:verify-work`:** Full suite green + all smoke tests pass
- **Max feedback latency:** ~30 seconds per static check; smoke tests are manual

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 5-01-01 | 01 | 1 | DEPL-03 | static | `grep libsqlite server/Dockerfile` | ✅ | ⬜ pending |
| 5-01-02 | 01 | 1 | DEPL-04 | static | `grep -A3 'def start' server/lib/mega_planner/application.ex` | ✅ | ⬜ pending |
| 5-01-03 | 01 | 1 | DEPL-02 | static | `grep -v release_command server/fly.toml && grep -A2 '\[mounts\]' server/fly.toml` | ✅ | ⬜ pending |
| 5-02-01 | 02 | 2 | DEPL-01 | smoke | `fly volumes list --app mega-planner-api` | ❌ W0 | ⬜ pending |
| 5-02-02 | 02 | 2 | DEPL-05 | smoke | `fly ssh console -C "ls -la /data/" --app mega-planner-api` | ❌ W0 | ⬜ pending |
| 5-02-03 | 02 | 2 | DEPL-06 | smoke | `fly logs --app mega-planner-api` | ❌ W0 | ⬜ pending |
| 5-03-01 | 03 | 3 | VRFY-01 | manual-only | Browser/curl testing against production URL | ❌ W0 | ⬜ pending |
| 5-03-02 | 03 | 3 | VRFY-02 | smoke | `fly deploy && fly ssh console -C "ls -la /data/" --app mega-planner-api` | ❌ W0 | ⬜ pending |
| 5-03-03 | 03 | 3 | VRFY-03 | smoke | `fly machine list --app mega-planner-api-db 2>&1 \| grep "No machines"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

None for ExUnit tests. All verifications are operational (Fly CLI smoke tests + manual browser testing) rather than ExUnit test files. The existing test suite can run via `cd server && mix test` to confirm no regressions.

*Existing infrastructure covers all automated (static) phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| All major features respond correctly in production | VRFY-01 | Requires live production environment; cannot automate against Fly.io in CI | Hit production URL for: auth (login/logout), tasks (create/list), budget, inventory, goals, habits — verify no 500 errors and data is correct |
| PostgreSQL cluster decommissioned after 48-hour window | VRFY-03 | Time-delayed operation; requires human judgment on rollback decision | After 48h with no issues: `fly postgres detach mega-planner-api-db --app mega-planner-api` then `fly apps destroy mega-planner-api-db` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s for static checks
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
