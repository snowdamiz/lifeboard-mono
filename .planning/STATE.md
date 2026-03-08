# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-07)

**Core value:** All production data survives the migration intact — zero data loss
**Current focus:** Phase 1 — Dependency & Config

## Current Position

Phase: 1 of 5 (Dependency & Config)
Plan: 0 of ? in current phase
Status: Ready to plan
Last activity: 2026-03-07 — Roadmap created; requirements defined and all 27 v1 requirements mapped to 5 phases

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: -
- Trend: -

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: `ecto_sqlite3` (not raw `exqlite`) is the mandated adapter — most actively maintained
- [Init]: Arrays and JSONB stored as JSON text in SQLite; schema field declarations unchanged
- [Init]: Export via Elixir Mix tasks (not pg_dump) for correct UUID encoding and type coercion
- [Init]: Single Fly.io volume (not LiteFS) — personal household app, single-writer is sufficient
- [Init]: Migrations run in `Application.start/2` — `release_command` in fly.toml has no volume access

### Pending Todos

None yet.

### Blockers/Concerns

- [Research gap]: `pool_size` in production — PITFALLS.md recommends 1, STACK.md recommends 5. Validate during Phase 3 local testing under simulated concurrent load.
- [Research gap]: `{:array, :binary_id}` schema field coercion in ecto_sqlite3 v0.22 — medium confidence. Validate during Phase 3 by writing and reading a record with a non-empty `linked_task_ids` field. Fallback: change schema field to `{:array, :string}`.
- [Research gap]: Production PostgreSQL export access method — verify exact Fly.io SSH tunnel / proxy approach before Phase 4 begins, as Fly CLI tooling has changed.

## Session Continuity

Last session: 2026-03-07
Stopped at: Roadmap created, STATE.md initialized. Ready to begin Phase 1 planning.
Resume file: None
