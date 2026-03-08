# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — PostgreSQL to SQLite Migration

**Shipped:** 2026-03-08
**Phases:** 5 | **Plans:** 16 | **Commits:** ~139

### What Was Built

- Complete adapter swap from postgrex to ecto_sqlite3 0.22.0 across all environments (dev/test/prod/runtime)
- Full rewrite of 60 Ecto migrations to SQLite-compatible SQL — PL/pgSQL → Elixir, partial indexes → raw SQL, JSONB → Elixir maps, ALTER COLUMN → table-rebuild pattern
- Replacement of 85 PostgreSQL-specific Ecto calls across the application (31 ilike→like, 54 foreign_key_constraint→validate_change, JSONB operator removal)
- Three-task data migration pipeline: mix migrate.export, mix migrate.import (two-pass FK), mix migrate.verify — covering all 48 production tables
- Production infrastructure configured: Dockerfile SQLite NIF layers, fly.toml volume mount, Application.start/2 migration wiring
- Live production export executed; 48 tables imported into SQLite with zero count discrepancies verified

### What Worked

- **Strict phase ordering**: Each phase had exactly one job (adapter → migrations → app code → data → infra). No phase tried to do two things. This made each phase predictable and the dependency chain clear.
- **verify-first pattern**: Running `mix ecto.reset` after every migration rewrite caught issues immediately instead of at integration gate.
- **execute fn -> pattern**: The `repo().query!/2` inside `execute fn ->` blocks became a reliable, reusable pattern for all SQLite migration data backfills.
- **Elixir export vs pg_dump**: Using Mix tasks for export gave full control over UUID encoding, Date/Time/Decimal type coercion, and JSON serialization. pg_dump would have created encoding mismatches.
- **Atomic task commits**: Every plan executed with per-task commits made the history readable and rollbacks straightforward.

### What Was Inefficient

- **ROADMAP.md showed stale status** for Phases 2 and 4 throughout execution — the progress table was not kept in sync with actual completion. Relied on disk_status from roadmap analyze instead.
- **Phase 5 not completed**: Plans 05-02 and 05-03 (actual Fly.io deploy and smoke testing) were left unexecuted before milestone completion. The operational steps require human action (fly CLI, SFTP) that can't be automated by Claude Code — this should have been planned as a separate human-action phase.
- **Blockers not resolved in STATE.md**: Three research gaps (pool_size in prod, binary_id array coercion, Fly proxy approach) were flagged at init but not formally resolved before completion. They remain as tech debt.

### Patterns Established

- **Two-pass FK insert**: For circular FKs (purchases↔budget_entries) and self-referential FKs (parent_task_id, parent_id), insert all rows with FK fields null first, then UPDATE to set them. Works reliably on both PostgreSQL and SQLite.
- **Table-rebuild for ALTER COLUMN nullability**: SQLite cannot alter column constraints after creation. Pattern: CREATE TABLE_new, INSERT INTO TABLE_new SELECT ..., DROP all indexes on old table, DROP TABLE, RENAME TABLE_new. Must include all columns present *at that migration's run time*, not current schema.
- **Application.start/2 migration location**: For Fly.io SQLite deployments, `release_command` has no volume access. Always wire `Release.migrate()` as the first call in `start/2`. Idempotent via schema_migrations.
- **libsqlite3 dual-stage Dockerfile**: `libsqlite3-dev` in builder (C headers for NIF compile) + `libsqlite3-0` in runner (shared lib for NIF load). Missing either causes a distinct failure mode.
- **validate_change/3 FK pattern**: ecto_sqlite3 surfaces FK violations as `[foreign_key: nil]` instead of an Ecto.ConstraintError that changesets can catch. Pre-insert `Repo.get/2` existence checks in validate_change/3 are the standard replacement.

### Key Lessons

1. **Separate code changes from operational steps**: The Fly.io deploy (create volume, sftp upload, fly deploy, smoke test) requires human CLI action that AI agents cannot execute. These steps should be planned as explicit human-action checkpoints in Phase 5, not bundled with code changes as if they're the same kind of work.
2. **ecto_sqlite3 JSON defaults require Elixir values**: `default: []` and `default: %{}` in migrations — not `default: "[]"` or `default: "{}"`. The string form stores literal characters that bypass serialization and produce garbage on read.
3. **PostgreSQL positional params don't work in SQLite**: `$1`, `$2` PostgreSQL params must be `?` in SQLite. Any migration using raw SQL must use `?` placeholders throughout.
4. **case_sensitive_like=OFF is ecto_sqlite3 default**: `like/2` in Ecto queries is case-insensitive for ASCII on ecto_sqlite3 by default, making it functionally equivalent to PostgreSQL's `ilike/2`. No additional configuration needed.
5. **pool_size matters for SQLite single-writer**: Production config uses pool_size: 5. PITFALLS.md recommends 1. This needs validation under real load — SQLite's single-writer lock means high pool sizes don't help and may cause contention.

### Cost Observations

- Model mix: claude-sonnet-4-6 throughout (balanced profile)
- Sessions: Multiple within 1 day (2026-03-07 → 2026-03-08)
- Notable: High commit velocity — 139 commits in 1 day. The atomic-commit-per-task pattern generates dense, readable history but creates many small commits.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~10 | 5 | First milestone — baseline established |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | mix test passing | SQLite adapter verified | ecto_sqlite3, exqlite |

### Top Lessons (Verified Across Milestones)

1. Separate human-action steps from agent-executable steps — plan them as distinct checkpoints
2. Verify-first within each phase — run integration gates before moving on, not after
