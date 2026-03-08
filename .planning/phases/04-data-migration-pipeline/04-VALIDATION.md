---
phase: 4
slug: data-migration-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-07
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in Elixir) |
| **Config file** | none — `mix test` alias in mix.exs |
| **Quick run command** | `cd /Users/sn0w/Documents/dev/lifeboard-mono/server && mix compile` |
| **Full suite command** | `cd /Users/sn0w/Documents/dev/lifeboard-mono/server && mix test` |
| **Estimated runtime** | ~5 seconds (compile check); ~15 seconds (full suite) |

---

## Sampling Rate

- **After every task commit:** Run `cd /Users/sn0w/Documents/dev/lifeboard-mono/server && mix compile`
- **After every plan wave:** Run `cd /Users/sn0w/Documents/dev/lifeboard-mono/server && mix test`
- **Before `/gsd:verify-work`:** Full suite must be green + all manual DATA checks complete
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 4-01-01 | 01 | 0 | DATA-01 | compile | `cd server && mix compile` | ❌ W0 | ⬜ pending |
| 4-01-02 | 01 | 1 | DATA-01 | compile | `cd server && mix compile` | ❌ W0 | ⬜ pending |
| 4-02-01 | 02 | 1 | DATA-02 | compile | `cd server && mix compile` | ❌ W0 | ⬜ pending |
| 4-02-02 | 02 | 1 | DATA-02 | compile | `cd server && mix compile` | ❌ W0 | ⬜ pending |
| 4-03-01 | 03 | 1 | DATA-03 | compile | `cd server && mix compile` | ❌ W0 | ⬜ pending |
| 4-04-01 | 04 | 2 | DATA-04 | manual | `fly proxy 5432:5432 -a mega-planner-api-db && mix migrate.export /tmp/export.json` | manual-only | ⬜ pending |
| 4-05-01 | 05 | 2 | DATA-05 | manual | `mix migrate.import /tmp/export.json && sqlite3 mega_planner_dev.db "PRAGMA foreign_key_check"` | manual-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `server/lib/mix/tasks/migrate.export.ex` — stub for DATA-01
- [ ] `server/lib/mix/tasks/migrate.import.ex` — stub for DATA-02
- [ ] `server/lib/mix/tasks/migrate.verify.ex` — stub for DATA-03
- [ ] `server/mix.exs` — add `{:postgrex, "~> 0.21", only: [:dev, :test]}` dep entry
- [ ] `server/lib/mix/tasks/` directory — must be created (does not exist yet)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Export produces valid JSON with all 48 table keys | DATA-01 | Requires live production PostgreSQL connection via fly proxy | `mix migrate.export /tmp/test_export.json && jq 'keys' /tmp/test_export.json \| wc -l` (should be 48) |
| Import inserts all rows into SQLite | DATA-02 | Requires the JSON export file from production | `mix migrate.import /tmp/export.json` then spot check counts |
| Verify reports zero discrepancies | DATA-03 | Requires both PostgreSQL tunnel and SQLite | `POSTGRES_URL=... mix migrate.verify` — output must show 0 discrepancies |
| Production export is complete and non-empty | DATA-04 | Requires fly proxy tunnel to live DB | `wc -c /tmp/export.json` > 0; spot check `goals.linked_task_ids`, `habits.linked_inventory_ids`, `brands.default_tags` for readable UUID strings |
| PRAGMA foreign_key_check returns 0 rows | DATA-05 | SQLite integrity check after import | `sqlite3 mega_planner_dev.db "PRAGMA foreign_key_check"` returns empty |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
