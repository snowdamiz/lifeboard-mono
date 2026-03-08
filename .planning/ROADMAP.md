# Roadmap: Lifeboard — PostgreSQL to SQLite Migration

## Overview

This roadmap migrates the Lifeboard Phoenix/Elixir app from a managed PostgreSQL cluster on Fly.io to a SQLite file on a persistent Fly.io volume. The migration proceeds in strict dependency order: swap the adapter and rewrite PostgreSQL-specific migrations first (so `mix ecto.migrate` works on SQLite), fix application code next (so the app boots cleanly), then build and verify the data pipeline, and finally execute the production cutover. Zero data loss is the non-negotiable constraint at every stage.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Dependency & Config** - Swap ecto_sqlite3 for postgrex in mix.exs and update all Ecto config files (completed 2026-03-08)
- [ ] **Phase 2: Migration Rewrites** - Rewrite PostgreSQL-specific migration files and verify clean `mix ecto.migrate` on SQLite
- [x] **Phase 3: Application Code Fixes** - Remove all SQLite-incompatible Ecto calls so the app boots and serves requests without runtime errors (completed 2026-03-08)
- [ ] **Phase 4: Data Migration Pipeline** - Build and run the export-import-verify pipeline that moves all production data from PostgreSQL to SQLite
- [ ] **Phase 5: Fly.io Deployment & Cutover** - Configure Fly.io volume, deploy the SQLite-backed image, smoke test, and decommission PostgreSQL

## Phase Details

### Phase 1: Dependency & Config
**Goal**: The adapter and all config files are switched to SQLite so the project can compile and the Repo connects to a local SQLite file
**Depends on**: Nothing (first phase)
**Requirements**: DEPS-01, DEPS-02, DEPS-03, DEPS-04, DEPS-05
**Success Criteria** (what must be TRUE):
  1. `mix deps.get` completes with `ecto_sqlite3` present and `postgrex` absent from the dependency tree
  2. `mix compile` succeeds with no warnings about unknown adapter modules
  3. `config/dev.exs`, `config/prod.exs`, `config/runtime.exs`, and `config/test.exs` all reference `Ecto.Adapters.SQLite3` — no PostgreSQL adapter references remain
  4. `DATABASE_PATH` env var is used in prod/runtime configs; `DATABASE_URL` references are removed
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Swap postgrex for ecto_sqlite3 in mix.exs, change Repo adapter, add migration_primary_key config
- [x] 01-02-PLAN.md — Replace PostgreSQL connection blocks in dev.exs, test.exs, and runtime.exs with SQLite3 equivalents

### Phase 2: Migration Rewrites
**Goal**: All Ecto migration files are SQLite-compatible so `mix ecto.migrate` runs from scratch against a fresh SQLite file without errors
**Depends on**: Phase 1
**Requirements**: MIGR-01, MIGR-02, MIGR-03, MIGR-04
**Success Criteria** (what must be TRUE):
  1. `mix ecto.reset` completes without errors on a fresh local SQLite file (all ~30 tables created)
  2. `grep -rn ":jsonb\|gen_random_uuid" priv/repo/migrations/` returns zero results
  3. The partial unique index in the inventory migration is expressed as a raw `execute` SQL statement with `WHERE purchased = 0`
  4. The PL/pgSQL anonymous block in migration 13 is replaced with Elixir Repo calls using `Ecto.UUID.generate/0`
**Plans**: 3 plans

Plans:
- [ ] 02-01-PLAN.md — Fix migration 04 partial index (purchased = 0) and migration 17 :jsonb types
- [ ] 02-02-PLAN.md — Replace PL/pgSQL block in migration 13 with Elixir execute fn ->
- [ ] 02-03-PLAN.md — Run mix ecto.reset to verify all ~60 migrations pass on fresh SQLite

### Phase 3: Application Code Fixes
**Goal**: The application boots against SQLite and handles all requests without runtime Ecto errors caused by PostgreSQL-only query functions
**Depends on**: Phase 2
**Requirements**: CODE-01, CODE-02, CODE-03, CODE-04
**Success Criteria** (what must be TRUE):
  1. `grep -rn "ilike" lib/` returns zero results — all case-insensitive search uses `like/2`
  2. `mix test` passes against the local SQLite database with zero failures caused by adapter incompatibility
  3. All ExUnit test cases that use database connections are marked `async: false`
  4. All Ecto query fragments using JSONB operators (`->`, `->>`, `@>`, `?`) have been replaced or removed from context modules
**Plans**: 4 plans

Plans:
- [ ] 03-01-PLAN.md — Replace 31 ilike → like calls in 5 context modules; create DataCase + AccountsFixtures; fix async: false
- [ ] 03-02-PLAN.md — Replace 27 foreign_key_constraint calls with validate_change/3 in receipts, calendar, goals schemas
- [ ] 03-03-PLAN.md — Replace 27 foreign_key_constraint calls with validate_change/3 in inventory, accounts, budget, notes, notifications, households, tags schemas
- [ ] 03-04-PLAN.md — Verify CODE-04 (no JSONB operators); run mix test integration gate; human checkpoint

### Phase 4: Data Migration Pipeline
**Goal**: All production data is exported from PostgreSQL, imported into a local SQLite file, and verified as complete with zero record count discrepancies
**Depends on**: Phase 3
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, DATA-05
**Success Criteria** (what must be TRUE):
  1. `mix migrate.export` runs against production PostgreSQL and produces a complete JSON export covering all 48 tables with no missing records or serialization errors
  2. `mix migrate.import` inserts all exported rows into the local SQLite database, including the two-pass insert for self-referential FKs (tasks.parent_task_id, goal_categories.parent_id) and circular FKs (purchases <-> budget_entries)
  3. `mix migrate.verify` reports zero discrepancies across all table record counts
  4. Spot checks on `goals.linked_task_ids`, `habit_inventories.linked_inventory_ids`, and `brands.default_tags` confirm UUID values are stored as readable strings (not binary blobs)
  5. `PRAGMA foreign_key_check` on the SQLite file returns zero rows
**Plans**: 4 plans

Plans:
- [ ] 04-01-PLAN.md — Add postgrex dev dep to mix.exs; implement mix migrate.export task with serialize/1 type coercion
- [ ] 04-02-PLAN.md — Implement mix migrate.import (two-pass FK handling) and mix migrate.verify tasks
- [ ] 04-03-PLAN.md — Run production export via fly proxy tunnel (human-action checkpoint)
- [ ] 04-04-PLAN.md — Run import + verify against local SQLite; Phase 4 integration gate

### Phase 5: Fly.io Deployment & Cutover
**Goal**: The app is running in production on SQLite with data persisting across restarts, and the PostgreSQL cluster is decommissioned after a 48-hour rollback window
**Depends on**: Phase 4
**Requirements**: DEPL-01, DEPL-02, DEPL-03, DEPL-04, DEPL-05, DEPL-06, VRFY-01, VRFY-02, VRFY-03
**Success Criteria** (what must be TRUE):
  1. The Fly.io app boots after deploy and `fly ssh console -C "ls -la /data/"` shows the SQLite file on the persistent volume (not ephemeral storage)
  2. All major features — auth, tasks, budget, inventory, goals, habits — respond correctly in smoke testing against the production SQLite deployment
  3. A second `fly deploy` (no-op redeploy) confirms the SQLite file survives container restart and all data remains intact
  4. Database migrations do not re-run on deploy (migrations run in `Application.start/2` and the schema version table prevents re-application)
  5. The PostgreSQL cluster is decommissioned after the 48-hour rollback window passes with no issues
**Plans**: 3 plans

Plans:
- [ ] 05-01-PLAN.md — Add SQLite libs to Dockerfile, remove release_command from fly.toml, add volume mount, wire Application.start/2 migrate()
- [ ] 05-02-PLAN.md — Create Fly volume, set DATABASE_PATH secret, deploy twice with SFTP upload of SQLite DB
- [ ] 05-03-PLAN.md — Smoke test all features, confirm volume persistence across restart, decommission PostgreSQL after 48h

## Progress

**Execution Order:**
Phases execute in strict numeric order. Each phase is a prerequisite for the next.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Dependency & Config | 2/2 | Complete   | 2026-03-08 |
| 2. Migration Rewrites | 0/3 | Not started | - |
| 3. Application Code Fixes | 4/4 | Complete   | 2026-03-08 |
| 4. Data Migration Pipeline | 2/4 | In Progress|  |
| 5. Fly.io Deployment & Cutover | 0/3 | Not started | - |
