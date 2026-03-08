# Milestones

## v1.0 PostgreSQL to SQLite Migration (Shipped: 2026-03-08)

**Phases completed:** 5 phases, 16 plans
**Files modified:** 107 | **Timeline:** 1 day (2026-03-07 → 2026-03-08)
**Requirements:** 20/27 v1 requirements complete

**Key accomplishments:**
1. Swapped postgrex for ecto_sqlite3 0.22.0 and updated Repo + all environment configs across dev/test/prod/runtime
2. Rewrote all 60 migrations to SQLite-compatible — PL/pgSQL blocks → Elixir execute fn, partial indexes → raw SQL, JSONB types → Elixir maps, ALTER COLUMN → full table-rebuild pattern
3. Fixed 54 SQLite-incompatible Ecto calls — 31 ilike→like replacements, 54 foreign_key_constraint→validate_change conversions, JSONB operator audit
4. Built complete data migration pipeline — mix migrate.export/import/verify covering all 48 tables with type coercion and circular FK handling
5. Exported 48 tables from live production PostgreSQL via Fly proxy tunnel; imported into local SQLite with zero count discrepancies verified
6. Configured production infra — Dockerfile SQLite NIF libs (builder + runner stages), fly.toml volume mount, Application.start/2 migration wiring

### Known Gaps

Milestone completed with Phase 5 plans 05-02 and 05-03 unexecuted. These requirements are deferred:

- **DATA-04**: Run export against live production PostgreSQL — *completed (04-03-SUMMARY.md confirms export ran)*
- **DATA-05**: Run import+verify against local SQLite — *completed (04-04-SUMMARY.md confirms zero discrepancies)*
- **DEPL-01**: Create persistent Fly.io volume — pending execution
- **DEPL-05**: Upload verified SQLite file to Fly volume via sftp — pending execution
- **DEPL-06**: Deploy to Fly.io and confirm startup — pending execution
- **VRFY-01**: Smoke test all major features in production — pending execution
- **VRFY-02**: Confirm SQLite file persists across Fly.io restarts — pending execution
- **VRFY-03**: Keep PostgreSQL 48h then decommission — pending execution

*Note: The codebase is fully migration-ready. The remaining steps are operational (Fly.io volume + deploy + verification).*

---
