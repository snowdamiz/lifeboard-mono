# Lifeboard: PostgreSQL → SQLite Migration

## What This Is

Lifeboard is a Phoenix/Elixir + Vue 3 household management app. This project migrated the entire data layer from PostgreSQL to SQLite (single Fly.io volume), preserving all production data. The adapter swap, migration rewrites, application code fixes, data pipeline, and production infrastructure are complete. The remaining step is the Fly.io operational cutover (volume creation, SQLite file upload, deploy, and smoke testing).

## Core Value

All production data survives the migration intact — zero data loss is the non-negotiable constraint that drives every decision.

## Requirements

### Validated

- ✓ Phoenix/Ecto backend serving REST API — existing
- ✓ Household-based multi-tenant data model — existing
- ✓ JWT authentication via Guardian/Ueberauth — existing
- ✓ Fly.io deployment via Docker — existing
- ✓ Replace postgrex with ecto_sqlite3 0.22.0 across mix.exs and Repo — v1.0
- ✓ Update all Ecto config files (dev, test, prod, runtime) for SQLite adapter — v1.0
- ✓ Audit and rewrite all 60 migrations to be SQLite-compatible — v1.0
- ✓ Audit all schemas; arrays/JSONB stored as JSON text, no incompatible field types — v1.0
- ✓ Replace all PostgreSQL-specific Ecto calls in application code (ilike, foreign_key_constraint, JSONB ops) — v1.0
- ✓ Build mix migrate.export/import/verify pipeline covering all 48 tables — v1.0
- ✓ Export all 48 production tables from live PostgreSQL via Fly proxy tunnel — v1.0
- ✓ Import all data into local SQLite; mix migrate.verify reports zero discrepancies — v1.0
- ✓ Update Dockerfile with SQLite NIF libraries (libsqlite3-dev + libsqlite3-0) — v1.0
- ✓ Update fly.toml — remove release_command, add volume mount, add DATABASE_PATH env — v1.0
- ✓ Wire Application.start/2 to call Release.migrate() before supervisor starts — v1.0

### Active

- [ ] Create persistent Fly.io volume (lifeboard_data, mounted at /data)
- [ ] Upload verified SQLite file to Fly volume via fly sftp
- [ ] Deploy to Fly.io and confirm app starts with SQLite on volume
- [ ] Smoke test all major features in production (auth, tasks, budget, inventory, goals, habits)
- [ ] Confirm SQLite file persists across app restarts (volume correctly mounted)
- [ ] Decommission PostgreSQL cluster after 48-hour rollback window

### Out of Scope

- LiteFS / distributed SQLite replication — single volume is sufficient for a personal household app
- Turso / libSQL — adding a managed service defeats the simplification goal
- Changing application features — this is a database swap, not a feature change
- Moving away from Fly.io — deployment target stays the same
- Database backup tooling (SQLite snapshot to S3/R2) — deferred to v2.0

## Context

**Current state (v1.0):** Codebase fully SQLite-ready. 107 files modified. ~260K LOC Elixir total.

**Tech stack:** Phoenix/Elixir, Ecto + ecto_sqlite3 0.22.0, exqlite 0.35.0 NIF, Vue 3, Fly.io Docker deployment.

**Migration decisions validated:**
- export via Elixir Mix tasks (not pg_dump) correctly handled UUID encoding, Date/Time/Decimal type coercion
- Two-pass FK insert pattern handled 3 circular/self-referential cases (tasks.parent_task_id, goal_categories.parent_id, purchases↔budget_entries)
- ecto_sqlite3 default case_sensitive_like=OFF makes `like/2` equivalent to PostgreSQL `ilike/2` for ASCII

**Known issues / technical debt:**
- pool_size: 5 in production config — PITFALLS.md recommends 1 for SQLite. Validate under real production load after cutover.
- `{:array, :binary_id}` coercion in ecto_sqlite3 v0.22 — validate during smoke test that linked_task_ids/linked_inventory_ids read back correctly.
- 54 foreign_key_constraint→validate_change replacements do Repo.get pre-checks instead of constraint-level enforcement. FK integrity depends on app logic only (SQLite FK pragma is enabled but error surfacing differs).

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Single Fly volume (not LiteFS) | Personal household app, single-writer is fine, LiteFS adds significant ops complexity | ✓ Good — implemented in fly.toml, volume mount at /data |
| `ecto_sqlite3` adapter | Most actively maintained SQLite adapter for Ecto, good community support | ✓ Good — all 60 migrations and app code compatible after rewrites |
| Arrays → JSON text / Elixir maps | SQLite has no native array type; JSON text is the standard workaround in Ecto SQLite | ✓ Good — worked seamlessly; ecto_sqlite3 serializes Elixir values, not JSON strings |
| Export via Elixir scripts (not pg_dump) | Elixir scripts give full control over UUID encoding and type coercion for SQLite | ✓ Good — serialize/1 6-clause pattern handled all PostgreSQL types correctly |
| Migrations run in Application.start/2 | release_command VMs have no volume access; app process has /data mounted | ✓ Good — idempotent via schema_migrations table; confirmed safe pattern |
| ? positional params throughout migration SQL | SQLite uses ? not $1 PostgreSQL positional syntax | ✓ Good — used consistently via execute fn -> / repo().query!/2 pattern |
| validate_change/3 replaces foreign_key_constraint/3 | ecto_sqlite3 returns [foreign_key: nil] causing unhandled ConstraintError 500 instead of changeset errors | ✓ Good — eliminates 500s; pre-insert Repo.get checks enforce FK integrity at app layer |

---
*Last updated: 2026-03-08 after v1.0 milestone*
