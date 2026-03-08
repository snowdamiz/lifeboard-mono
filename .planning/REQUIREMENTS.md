# Requirements: Lifeboard PostgreSQL → SQLite Migration

**Defined:** 2026-03-07
**Core Value:** All production data survives the migration intact — zero data loss

## v1 Requirements

### Dependency & Config

- [x] **DEPS-01**: Replace `postgrex` with `ecto_sqlite3 ~> 0.22` in mix.exs and remove the postgrex dependency
- [x] **DEPS-02**: Upgrade `ecto_sql` from `~> 3.10` to `~> 3.13` (required by ecto_sqlite3 0.22.x)
- [x] **DEPS-03**: Update `config/dev.exs` to use `Ecto.Adapters.SQLite3` with a local `.db` file path
- [x] **DEPS-04**: Update `config/prod.exs` and `config/runtime.exs` to use `Ecto.Adapters.SQLite3` with `DATABASE_PATH` env var (replaces `DATABASE_URL`)
- [x] **DEPS-05**: Update `config/test.exs` to use `Ecto.Adapters.SQLite3` with a temp `.db` file for tests

### Migration Rewrites

- [x] **MIGR-01**: Rewrite migration `20260101000013` — replace the PL/pgSQL `DO $$ DECLARE ... gen_random_uuid() ... END $$;` block with Elixir using `repo().query!/2` and `Ecto.UUID.generate/0`
- [x] **MIGR-02**: Rewrite migration `20260101000017` — change `:jsonb` to `{:array, :map}` for `dashboard_widgets` and `:map` for `settings`
- [x] **MIGR-03**: Rewrite the partial unique index in the inventory migration — replace Ecto DSL `:where` option with a raw `execute` SQL statement using `WHERE purchased = 0` (SQLite boolean is integer)
- [x] **MIGR-04**: Run `mix ecto.migrate` against a fresh SQLite database and confirm all migrations complete without errors

### Application Code Fixes

- [x] **CODE-01**: Replace all `ilike/2` calls with `like/2` across all Ecto query files (35+ occurrences in `search.ex`, `inventory.ex`, `receipts.ex`, `goals.ex`, `templates.ex`)
- [x] **CODE-02**: Set `async: false` on all ExUnit test cases that use database connections (SQLite's single-writer model is incompatible with async sandbox)
- [x] **CODE-03**: Audit all `foreign_key_constraint/3` calls in changesets and replace with `validate_change/3` pre-validation checks that query for the referenced record's existence before insert
- [ ] **CODE-04**: Audit Ecto query fragments for any JSONB operators (`->`, `->>`, `@>`, `?`) that exist in context modules and replace or remove them

### Data Migration Pipeline

- [ ] **DATA-01**: Create `mix migrate.export` Mix task — connects to PostgreSQL via Ecto and exports all table data to a JSON file, serializing arrays and maps correctly
- [ ] **DATA-02**: Create `mix migrate.import` Mix task — reads the JSON export and inserts all records into SQLite, respecting foreign key ordering and handling the tasks self-referential FK (`parent_task_id`) with a two-pass insert
- [ ] **DATA-03**: Create `mix migrate.verify` Mix task — compares record counts between PostgreSQL and SQLite for every table and reports any discrepancies
- [ ] **DATA-04**: Run export against live production PostgreSQL database and produce a verified export file
- [ ] **DATA-05**: Run import against local SQLite database and confirm `mix migrate.verify` shows zero discrepancies

### Fly.io Deployment

- [ ] **DEPL-01**: Create a persistent Fly.io volume for the SQLite database file (e.g., `lifeboard_data`, mounted at `/data`)
- [ ] **DEPL-02**: Update `fly.toml` — remove `release_command` (has no volume access), add volume mount configuration
- [ ] **DEPL-03**: Update `Dockerfile` — add SQLite system library (`libsqlite3-dev` / equivalent), remove any PostgreSQL client tooling
- [ ] **DEPL-04**: Move database migration execution from `release_command` to `Application.start/2` via a `Release.migrate()` call
- [ ] **DEPL-05**: Upload the verified SQLite `.db` file to the Fly volume via `fly sftp` before deploying
- [ ] **DEPL-06**: Deploy to Fly.io and confirm the app starts, migrations do not re-run, and the volume-mounted database is used

### Verification & Cutover

- [ ] **VRFY-01**: Smoke test all major features against the SQLite-backed production deployment (auth, tasks, budget, inventory, goals, habits)
- [ ] **VRFY-02**: Confirm SQLite file persists across Fly.io app restarts (volume is correctly mounted and not ephemeral storage)
- [ ] **VRFY-03**: Keep PostgreSQL running for 48 hours after cutover as rollback option, then decommission

## v2 Requirements

### Polish

- **PLSH-01**: Add database backup tooling — periodic SQLite file snapshot to object storage (S3/R2)
- **PLSH-02**: Performance audit — SQLite pool_size is 1 vs PostgreSQL's 10; confirm no concurrency issues under real usage
- **PLSH-03**: Review any remaining `foreign_key_constraint/3` calls that were left as `Ecto.ConstraintError` raisers and decide on full pre-validation

## Out of Scope

| Feature | Reason |
|---------|--------|
| LiteFS distributed replication | Single-user household app; single writer is sufficient; LiteFS adds significant ops overhead |
| Turso / libSQL hosted SQLite | Adds a managed service dependency; defeats the simplification goal |
| Moving to a different framework | Database swap only; Phoenix/Ecto/Vue stack stays the same |
| Application feature changes | This milestone is purely a database migration; no behavior changes |
| Schema redesign | Migrating existing schema as-is; no normalization of array columns |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEPS-01 | Phase 1 | Complete |
| DEPS-02 | Phase 1 | Complete |
| DEPS-03 | Phase 1 | Complete |
| DEPS-04 | Phase 1 | Complete |
| DEPS-05 | Phase 1 | Complete |
| MIGR-01 | Phase 2 | Complete |
| MIGR-02 | Phase 2 | Complete |
| MIGR-03 | Phase 2 | Complete |
| MIGR-04 | Phase 2 | Complete |
| CODE-01 | Phase 3 | Complete |
| CODE-02 | Phase 3 | Complete |
| CODE-03 | Phase 3 | Complete |
| CODE-04 | Phase 3 | Pending |
| DATA-01 | Phase 4 | Pending |
| DATA-02 | Phase 4 | Pending |
| DATA-03 | Phase 4 | Pending |
| DATA-04 | Phase 4 | Pending |
| DATA-05 | Phase 4 | Pending |
| DEPL-01 | Phase 5 | Pending |
| DEPL-02 | Phase 5 | Pending |
| DEPL-03 | Phase 5 | Pending |
| DEPL-04 | Phase 5 | Pending |
| DEPL-05 | Phase 5 | Pending |
| DEPL-06 | Phase 5 | Pending |
| VRFY-01 | Phase 5 | Pending |
| VRFY-02 | Phase 5 | Pending |
| VRFY-03 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 27 total
- Mapped to phases: 27
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-07*
*Last updated: 2026-03-07 after roadmap creation*
