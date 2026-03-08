# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-07)

**Core value:** All production data survives the migration intact — zero data loss
**Current focus:** Phase 1 — Dependency & Config

## Current Position

Phase: 1 of 5 (Dependency & Config)
Plan: 1 of 2 in current phase
Status: In progress
Last activity: 2026-03-08 — Plan 01-01 complete: swapped postgrex for ecto_sqlite3, updated Repo adapter to SQLite3, added migration_primary_key config

Progress: [█░░░░░░░░░] 10%

## Performance Metrics

**Velocity:**
- Total plans completed: 1
- Average duration: 3 min
- Total execution time: 0.05 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-dependency-config | 1 | 3 min | 3 min |

**Recent Trend:**
- Last 5 plans: 3 min
- Trend: establishing baseline

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
- [01-01]: postgrex removed entirely (not kept optional) to prevent stale Postgres compile-time references
- [01-01]: migration_primary_key set at repo config level (not per-migration) for universal UUID binary_id inheritance

### Pending Todos

None yet.

### Blockers/Concerns

- [Research gap]: `pool_size` in production — PITFALLS.md recommends 1, STACK.md recommends 5. Validate during Phase 3 local testing under simulated concurrent load.
- [Research gap]: `{:array, :binary_id}` schema field coercion in ecto_sqlite3 v0.22 — medium confidence. Validate during Phase 3 by writing and reading a record with a non-empty `linked_task_ids` field. Fallback: change schema field to `{:array, :string}`.
- [Research gap]: Production PostgreSQL export access method — verify exact Fly.io SSH tunnel / proxy approach before Phase 4 begins, as Fly CLI tooling has changed.

## Session Continuity

Last session: 2026-03-08
Stopped at: Completed 01-01-PLAN.md — adapter swap complete, ready for 01-02 (env-specific database path config)
Resume file: None
