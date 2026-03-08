# Project Research Summary

**Project:** Lifeboard — PostgreSQL to SQLite Migration
**Domain:** Phoenix/Ecto database adapter swap with data migration pipeline on Fly.io
**Researched:** 2026-03-07
**Confidence:** HIGH

## Executive Summary

Lifeboard is a Phoenix/Ecto personal household planning app being migrated from PostgreSQL (Fly.io Postgres cluster) to SQLite (Fly.io persistent volume) to simplify operations and eliminate the managed database dependency. The canonical approach for this type of migration is: swap the Ecto adapter (`ecto_sqlite3 ~> 0.22`), rewrite the small number of PostgreSQL-specific migration files, audit application code for PostgreSQL-only Ecto DSL functions, then run a structured export-transform-import pipeline using Elixir Mix tasks that read from the live PostgreSQL database and write SQLite-compatible NDJSON. The result is a single `.db` file on a Fly.io volume with no external database dependency.

The recommended stack swap is minimal: remove `postgrex`, add `ecto_sqlite3 ~> 0.22`, upgrade `ecto_sql` to `~> 3.13`, and change the Repo adapter. Almost all schema and context code is portable without modification — `:map`, `{:array, :string}`, `{:array, :integer}`, and `:binary_id` all work identically under `ecto_sqlite3` with its default configuration. The two migrations that need rewriting (`20260101000013` with a PL/pgSQL block, and `20260101000017` with `:jsonb` columns) and the 35+ `ilike/2` calls scattered across search code are the only meaningful code changes.

The dominant risks are operational rather than architectural. The three most dangerous are: (1) `ilike/2` causing runtime 500 errors on every search endpoint immediately after switching adapters — it is silently incompatible; (2) the `release_command` in `fly.toml` failing silently because it runs without volume access, leaving the deployed app with an unmigrated or missing database; and (3) data stored on the ephemeral container filesystem rather than the Fly volume, causing silent total data loss on every deploy. All three are entirely preventable with the checklist from PITFALLS.md.

## Key Findings

### Recommended Stack

The adapter swap requires only four changes: add `ecto_sqlite3 ~> 0.22` (which pulls in `exqlite ~> 0.22` transitively), remove `postgrex`, upgrade `ecto_sql` to `~> 3.13` (the current project pins `~> 3.10`), and change `MegaPlanner.Repo` to use `Ecto.Adapters.SQLite3`. All other dependencies (`jason`, `decimal`, `phoenix_ecto`) are already compatible. The Dockerfile needs `libsqlite3-dev` in the build stage and `libsqlite3-0` in the runner stage for the Exqlite NIF.

See `.planning/research/STACK.md` for exact `mix.exs` diffs, per-environment config changes, and the `fly.toml` volume mount configuration.

**Core technologies:**
- `ecto_sqlite3 ~> 0.22`: Ecto 3.x SQLite adapter — the only actively maintained option; first-class support for binary_id, WAL, JSON maps/arrays
- `exqlite ~> 0.22` (transitive): NIF-based SQLite3 driver — do not pin directly; pulled by ecto_sqlite3
- `ecto_sql ~> 3.13`: Required by ecto_sqlite3 0.22.x; current project must upgrade from `~> 3.10`
- `Fly.io persistent volume`: Single-machine block storage at `/data`; replaces the Postgres cluster entirely

### Expected Features (Migration Scope)

This is a migration project, not a greenfield build. "Features" are the PostgreSQL-specific constructs that must be correctly ported. See `.planning/research/FEATURES.md` for full per-column detail.

**Must fix before any SQLite testing (migration blockers):**
- PL/pgSQL anonymous block in migration 13 — crashes SQLite immediately; replace with Elixir `Repo` calls using `Ecto.UUID.generate/0`
- `:jsonb` column type in migration 17 — not recognized by ecto_sqlite3; rewrite to `:map` / `{:array, :map}`
- `{:array, :type}` migration declarations — must become `:text` in migrations (schema field declarations are unchanged)
- `ilike/2` in 35+ application code locations — raises `Ecto.QueryError` at runtime; replace with `like/2`

**Works without changes (portably compatible):**
- `{:array, :string}`, `{:array, :integer}`, `{:array, :binary_id}` schema field declarations — ecto_sqlite3 handles JSON serialization automatically
- `:map` columns across all tables — serialized as JSON text, decoded back on read
- `:binary_id` primary keys with `autogenerate: true` — UUID generation is already in Elixir, not the DB
- `fragment/1` with `LOWER()`, `UPPER()`, `TRIM()`, `COALESCE()` — all are SQLite core scalar functions
- All 28+ migrations except migrations 13 and 17

**Partial support (monitor during implementation):**
- `{:array, :binary_id}` sub-type coercion during export — UUIDs must be string-encoded via `Ecto.UUID.load!/1` before JSON encoding; the schema type works but the export script must handle it explicitly
- `foreign_key_constraint/3` in changesets — SQLite does not surface constraint names; will raise `Ecto.ConstraintError` instead of field-level errors; low risk (no strict FK error handling found in codebase)

**Defer to post-migration cleanup:**
- `foreign_key_constraint/3` audit — replace with pre-validation in changesets if strict error messaging is needed
- `async: false` test configuration — all DB tests must switch from `async: true`; low urgency if tests pass

### Architecture Approach

The migration pipeline follows a strict five-stage sequence: Schema Prep (rewrite and run SQLite-compatible migrations locally) → Export (Mix task using `Repo.stream` against production PostgreSQL via SSH tunnel, writing one NDJSON file per table) → Transform (inline coercions: `Jason.encode!` for all array/map columns, ISO 8601 for dates/times, `Ecto.UUID.load!/1` for UUID arrays) → Import (direct Exqlite calls, `PRAGMA foreign_keys = OFF` before `BEGIN`, tiered insert order to respect FK dependencies) → Verify (record count comparison + `PRAGMA foreign_key_check` + row-level spot checks). The cutover is a ~15-minute maintenance window: upload the verified SQLite file to the Fly volume, deploy the new image, smoke test, confirm.

See `.planning/research/ARCHITECTURE.md` for the complete pipeline, exact `fly.toml` contents, Dockerfile changes, and the 12-step cutover sequence with rollback plan.

**Major components:**
1. **Migration rewrite** — 3 migration files changed; all others are compatible as-is
2. **Application code audit** — `ilike` → `like` across 35+ locations; test suite `async: false`
3. **Export Mix task** (`mix migrate.export`) — streams PostgreSQL tables to NDJSON files using existing Repo
4. **Import Mix task** (`mix migrate.import`) — inserts NDJSON rows into SQLite via Exqlite, bypassing changesets
5. **Verify Mix task** (`mix migrate.verify`) — compares counts and runs `PRAGMA foreign_key_check`
6. **Fly.io config** — volume creation, `fly.toml` mounts, `DATABASE_PATH` env var, `runtime.exs` rewrite
7. **Application startup migration** — `Release.migrate()` called in `Application.start/2` (not `release_command`)

### Critical Pitfalls

1. **`ilike/2` causes runtime 500s on all search endpoints** — Replace every occurrence with `like/2` before testing against SQLite. Run `grep -rn "ilike" lib/` and expect ~35 results. No compile-time warning — these fail only at runtime. This is the highest-impact application code change.

2. **PL/pgSQL block in migration 13 hard-crashes `mix ecto.migrate`** — The `DO $$ DECLARE ... gen_random_uuid() ... END $$;` block is PostgreSQL-only and will fail immediately against SQLite. Rewrite using Elixir `repo().query!/2` and `Ecto.UUID.generate/0`. This blocks the entire migration chain from running.

3. **`release_command` in `fly.toml` silently skips migrations** — Fly's `release_command` runs without volume access; the SQLite file does not exist on the ephemeral machine. Remove `release_command` from `fly.toml` entirely and call `MegaPlanner.Release.migrate()` in `Application.start/2`.

4. **SQLite file on ephemeral container filesystem = silent total data loss on every deploy** — If `DATABASE_PATH` points outside the Fly volume mount (`/data`), all data is lost when the container restarts. Validate with `fly ssh console -C "ls -la /data/"` after every deploy during setup.

5. **UUID arrays corrupted during export if not string-encoded** — `{:array, :binary_id}` columns (`goals.linked_task_ids`, `habits.linked_inventory_ids`, `brands.default_tags`) must explicitly call `Ecto.UUID.load!/1` on each element before `Jason.encode!`. Raw export via SQL (not through Ecto schemas) may produce binary blobs in the JSON array, causing all lookups against those columns to silently return nothing.

## Implications for Roadmap

Based on research, this is a 5-phase migration project with strict ordering — phases cannot be parallelized because each stage depends on the previous one being verified. The total effort is bounded: a personal household app with ~30 tables and a small dataset means the data pipeline is fast, but the code audit and migration rewrites have no shortcuts.

### Phase 1: Migration Audit and Rewrite

**Rationale:** All other phases depend on a clean SQLite schema. The migration files must run from scratch via `mix ecto.reset` before any import work begins. This is the prerequisite gate for everything else.

**Delivers:** A local SQLite database with all ~30 tables created correctly. `mix ecto.create && mix ecto.migrate` completes without errors on a fresh SQLite file.

**Addresses:**
- Pitfall 1: PL/pgSQL block in migration 13 — replace with Elixir Repo calls
- Pitfall 6: `:jsonb` column type — rewrite to `:map` / `{:array, :map}`
- Pitfall 7: `{:array, :type}` in migrations — rewrite to `:text` columns

**Verification gate:** `mix ecto.reset` runs cleanly; `grep -rn ":jsonb\|gen_random_uuid" priv/repo/migrations/` returns zero results.

**Research flag:** Standard patterns — no additional research needed. STACK.md and FEATURES.md have exact before/after code for every change.

### Phase 2: Application Code Audit

**Rationale:** Application code changes must be done before any local SQLite testing. The `ilike` issue produces runtime errors that could be misdiagnosed as data migration problems if not fixed first.

**Delivers:** Application code that boots and handles requests against a SQLite backend without runtime Ecto errors.

**Addresses:**
- Pitfall 5: `ilike/2` → `like/2` across 35+ locations in search, inventory, receipts, goals, templates
- Test suite: all modules using `Ecto.Adapters.SQL.Sandbox` must set `async: false`

**Verification gate:** `grep -rn "ilike" lib/` returns zero results; `mix test` passes against local SQLite.

**Research flag:** Standard patterns — mechanical substitution (`ilike` → `like`). No research needed.

### Phase 3: Adapter Swap and Local Verification

**Rationale:** With clean migrations and compatible application code, the adapter swap itself is a small config change. Doing it after phases 1-2 means the first boot against SQLite has a clean slate.

**Delivers:** The application running locally against SQLite. `mix phx.server` boots, auth works, all major endpoints respond without errors.

**Uses:**
- `ecto_sqlite3 ~> 0.22` replacing `postgrex`
- `ecto_sql ~> 3.13` (upgraded from `~> 3.10`)
- WAL mode, `pool_size: 5`, `busy_timeout: 5000` in dev config

**Addresses:**
- Stack version compatibility matrix (STACK.md)
- Correct `binary_id_type: :string` default (no change needed)
- Correct `map_type: :string` default (no change needed)

**Verification gate:** Application boots; `mix phx.server` starts without errors; login, task list, and budget endpoints return data (using any manually inserted seed data).

**Research flag:** Standard patterns — STACK.md has exact config diffs for all files.

### Phase 4: Data Export and Import Pipeline

**Rationale:** The migration tooling (Mix tasks) is the most complex implementation work and must be built after the adapter swap is verified locally. The export runs against production PostgreSQL (which is still running); the import targets the new local SQLite file.

**Delivers:** Four Mix tasks (`migrate.export`, `migrate.transform`, `migrate.import`, `migrate.verify`) that collectively move all production data from PostgreSQL to SQLite with verified integrity.

**Implements:**
- Export Mix task: `Repo.stream` per table in FK dependency order → NDJSON files
- Type coercions: `Jason.encode!` for all arrays/maps, `Date.to_iso8601/1`, `DateTime.to_iso8601/1`, `Ecto.UUID.load!/1` for UUID array elements
- Import Mix task: Direct Exqlite inserts, `PRAGMA foreign_keys = OFF` outside `BEGIN`, tiered table order
- Verify Mix task: Count comparison + `PRAGMA foreign_key_check` + row-level spot checks on UUID array columns

**Avoids:**
- Pitfall 2: UUID binary corruption — explicit `Ecto.UUID.load!/1` on `{:array, :binary_id}` columns
- Pitfall 8: Schema migrations ordering — export runs against PostgreSQL; SQLite schema created fresh by migrations; import only adds data rows
- Anti-pattern: pg_dump — always use `Repo.stream` to get properly decoded Elixir values

**Verification gate:** Record counts match across all ~30 tables; `PRAGMA foreign_key_check` returns zero rows; spot checks on `goals.linked_task_ids`, `habits.linked_inventory_ids`, `brands.default_tags` return valid UUID strings.

**Research flag:** Moderate complexity — ARCHITECTURE.md has exact code patterns for the export and import tasks, but the self-referential `tasks.parent_task_id` column needs a two-pass import (insert all tasks with `parent_task_id = NULL`, then UPDATE). This is documented in ARCHITECTURE.md.

### Phase 5: Fly.io Volume and Deployment Cutover

**Rationale:** Infrastructure configuration and the cutover itself are the final phase. The SQLite file is verified locally before any production change is made.

**Delivers:** The application running in production against SQLite on a Fly.io persistent volume. PostgreSQL cluster is kept alive for 48 hours as rollback option, then destroyed.

**Addresses:**
- Pitfall 3: `release_command` removed from `fly.toml`; migrations run in `Application.start/2`
- Pitfall 4: Volume mounted at `/data`; `DATABASE_PATH=/data/lifeboard.db` in `[env]`
- Dockerfile: `libsqlite3-dev` (build) and `libsqlite3-0` (runner) added
- `fly secrets unset DATABASE_URL`; `DATABASE_PATH` set as env var in `fly.toml`

**Cutover sequence:**
1. Create volume: `fly volumes create lifeboard_data --region iad --size 3`
2. Run production export via SSH tunnel
3. Transform + import locally
4. Verify locally
5. Upload verified `.db` file to Fly volume
6. `fly deploy` with new image and `fly.toml`
7. Smoke test; confirm data persists across a second deploy
8. After 48h, destroy PostgreSQL cluster

**Research flag:** Standard patterns — ARCHITECTURE.md has exact `fly.toml` contents, Dockerfile diffs, and the full 12-step cutover sequence. The rollback plan (revert to previous image + keep PostgreSQL alive) is also documented.

### Phase Ordering Rationale

- Phase 1 before Phase 3: Migrations must run cleanly on SQLite before the adapter is live in the app. Running `mix ecto.reset` validates migration correctness in isolation.
- Phase 2 before Phase 3: `ilike` errors would produce misleading failures during first-boot testing if not fixed first.
- Phase 3 before Phase 4: The export Mix task needs the `ecto_sqlite3` adapter available; the import Mix task needs a valid SQLite schema to write into.
- Phase 4 before Phase 5: Never deploy to production without a verified data file. The export-import pipeline is designed to be run locally and the resulting `.db` file uploaded, not built in-place on the production volume.
- Phase 5 last: Fly.io infrastructure changes (volume creation, `fly.toml` changes) should only be applied when the local data file is verified and ready to deploy.

### Research Flags

Phases with standard, well-documented patterns (no additional research needed during planning):
- **Phase 1:** Exact migration rewrites are in FEATURES.md and PITFALLS.md with before/after code.
- **Phase 2:** Mechanical `ilike` → `like` substitution; documented in PITFALLS.md with grep command.
- **Phase 3:** Exact config diffs for every file are in STACK.md.
- **Phase 5:** Exact `fly.toml`, Dockerfile, and secrets changes are in ARCHITECTURE.md.

Phases that may benefit from deeper research during planning:
- **Phase 4:** The export Mix task structure is well-documented, but production access patterns (direct SSH tunnel vs. `fly ssh console` vs. `fly proxy`) should be verified against current Fly.io tooling. The `tasks.parent_task_id` self-referential two-pass import is straightforward but should be explicitly planned.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All versions verified against hex.pm and hexdocs as of research date; exact config diffs provided |
| Features | HIGH | Per-column analysis of all 30+ tables; verified against ecto_sqlite3 v0.22.0 source and docs |
| Architecture | HIGH | Based on Fly.io official SQLite guide, ecto_sqlite3 official docs, SQLite official docs |
| Pitfalls | HIGH | Each pitfall verified against official sources or GitHub issues; includes codebase-specific audit (35+ ilike occurrences confirmed) |

**Overall confidence:** HIGH

### Gaps to Address

- **`pool_size` in production:** PITFALLS.md technical debt table suggests `pool_size: 1` for writes to avoid `SQLITE_BUSY`, while STACK.md and ARCHITECTURE.md recommend `pool_size: 5`. The gap is: does the Lifeboard app have concurrent write paths (multiple simultaneous API requests)? If yes, consider `pool_size: 1` with `busy_timeout: 5000`. If not (single-user household app with serialized requests), `pool_size: 5` is fine. Validate during Phase 3 local testing under simulated load.

- **`{:array, :binary_id}` schema field in ecto_sqlite3:** FEATURES.md notes MEDIUM confidence on whether `{:array, :binary_id}` schema declarations work cleanly for sub-type coercion in ecto_sqlite3. The fallback (change schema field to `{:array, :string}`) is documented and safe. Validate during Phase 3 by writing and reading a record with a non-empty `linked_task_ids` field.

- **Production export access method:** The architecture assumes SSH tunnel or `fly ssh console` access to production PostgreSQL during the export phase. Verify the exact Fly.io access pattern before Phase 4 begins, as Fly CLI tooling for SSH proxy has changed in recent versions.

## Sources

### Primary (HIGH confidence)
- [Ecto.Adapters.SQLite3 — ecto_sqlite3 v0.22.0 official docs](https://hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html) — adapter config options, UUID handling, array/map type support, PRAGMA defaults
- [ecto_sqlite3 hex.pm package](https://hex.pm/packages/ecto_sqlite3) — version 0.22.0 verified current
- [ecto_sql hex.pm](https://hex.pm/packages/ecto_sql) — latest version 3.13.5 verified as of Mar 3 2026
- [Fly.io Elixir SQLite3 guide](https://fly.io/docs/elixir/advanced-guides/sqlite3/) — volume setup, migration startup pattern, release_command caveat
- [Fly.io volumes overview](https://fly.io/docs/volumes/overview/) — ephemeral storage warning, volume creation, one-to-one machine mapping
- [SQLite official docs — PRAGMA foreign_keys](https://sqlite.org/foreignkeys.html) — cannot toggle PRAGMA inside transaction
- [SQLite official docs — PRAGMA statements](https://sqlite.org/pragma.html) — full PRAGMA reference
- [SQLite core scalar functions](https://sqlite.org/lang_corefunc.html) — LOWER, UPPER, TRIM, COALESCE confirmed built-in
- [SQLite partial index documentation](https://www.sqlite.org/partialindex.html) — WHERE clause support confirmed
- [Ecto.UUID — Ecto v3.13.5](https://hexdocs.pm/ecto/Ecto.UUID.html) — generate/0, load!/1 behavior

### Secondary (MEDIUM confidence)
- [ecto_sqlite3 GitHub issue #70 — binary_id_type configuration](https://github.com/elixir-sqlite/ecto_sqlite3/issues/70) — UUID encoding behavior differences
- [ecto_sqlite3 GitHub issue #51 — UUID handling](https://github.com/elixir-sqlite/ecto_sqlite3/issues/51) — binary_id with string storage confirmed
- [ecto_sqlite3 GitHub issue #42 — foreign_key_constraint support](https://github.com/elixir-sqlite/ecto_sqlite3/issues/42) — constraint name mapping limitation
- [ecto_sqlite3 GitHub issue #99 — concurrent sandbox](https://github.com/elixir-sqlite/ecto_sqlite3/issues/99) — async: true deadlock behavior
- [Fly.io community — migration with sqlite3 on volume fails](https://community.fly.io/t/migration-in-sqlite3-on-volume-fails/3818) — release_command volume access confirmed broken
- [Fly.io community — SQLite lost after deployment](https://community.fly.io/t/sqlite-lost-after-deployment/9852) — ephemeral storage data loss pattern
- [Phoenix + SQLite deployment tips gist (mcrumm)](https://gist.github.com/mcrumm/98059439c673be7e0484589162a54a01) — Application.start/2 migration pattern
- [Wawandco blog — PostgreSQL to SQLite on Fly.io migration](https://wawand.co/blog/posts/tech-tales-fly-sqlite-and-postgres/) — real-world migration experience

---
*Research completed: 2026-03-07*
*Ready for roadmap: yes*
