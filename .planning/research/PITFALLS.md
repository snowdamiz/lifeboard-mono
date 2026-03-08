# Pitfalls Research

**Domain:** Phoenix/Ecto PostgreSQL-to-SQLite migration (Fly.io deployment)
**Researched:** 2026-03-07
**Confidence:** HIGH — based on ecto_sqlite3 official docs, Fly.io docs, GitHub issues, and direct codebase audit

---

## Critical Pitfalls

### Pitfall 1: PL/pgSQL Block in Migration 13 Will Hard-Crash SQLite

**What goes wrong:**
Migration `20260101000013_add_household_id_to_data_tables.exs` contains a raw `execute/1` call with a PostgreSQL `DO $$ DECLARE ... BEGIN ... END $$;` block using `gen_random_uuid()`. SQLite has no stored-procedure language and no `gen_random_uuid()` function. Running this migration against SQLite fails immediately with a syntax error. Because Ecto wraps each migration in a transaction, the entire migration is rolled back and the schema is left incomplete.

**Why it happens:**
The migration uses a data-migration pattern (backfilling `household_id` for every user) implemented as a PL/pgSQL anonymous block — a PostgreSQL-only construct. There is no equivalent in SQLite's SQL dialect.

**How to avoid:**
Replace the anonymous block entirely with Elixir code in the migration's `up/0` function. The correct pattern:

```elixir
def up do
  # Create the column first
  alter table(:users) do
    add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
  end

  # Backfill using Elixir + Repo
  # This runs AFTER the migration schema changes are applied
  flush()  # ensures column exists before SELECT

  MegaPlanner.Repo.all(
    from u in "users",
    where: is_nil(u.household_id),
    select: %{id: u.id, name: u.name, email: u.email}
  )
  |> Enum.each(fn user ->
    household_id = Ecto.UUID.generate()
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    MegaPlanner.Repo.insert_all("households", [
      %{id: household_id, name: "#{user.name || user.email}'s Household",
        inserted_at: now, updated_at: now}
    ])
    MegaPlanner.Repo.update_all(
      from(u in "users", where: u.id == ^user.id),
      set: [household_id: household_id]
    )
  end)
end
```

**Warning signs:**
- Any `execute/1` call containing `$$`, `DECLARE`, `BEGIN`, `LOOP`, `END LOOP`, or function names like `gen_random_uuid()`, `uuid_generate_v4()`, `NOW()`, `COALESCE` inside a PL/pgSQL block.
- Run `grep -rn "DO \$\$\|gen_random_uuid\|DECLARE" priv/repo/migrations/` before switching adapters.

**Phase to address:** Phase 1 (Migration Audit and Rewrite) — this is the highest-priority rewrite because it blocks the entire migration chain from running.

---

### Pitfall 2: `{:array, :binary_id}` Columns Store UUIDs as Raw Bytes; Cross-Adapter Export Corrupts Them

**What goes wrong:**
Three columns use `{:array, :binary_id}` in migrations:
- `goals.linked_task_ids`
- `habits.linked_inventory_ids`
- `brands.default_tags`

In PostgreSQL, `:binary_id` arrays store UUIDs as native UUID type. When exported via Ecto queries, these arrive as binary strings. In SQLite with `ecto_sqlite3`, arrays are serialized as JSON text (e.g., `["<uuid1>","<uuid2>"]`). If the export step doesn't explicitly convert binary UUIDs to their string representation before JSON-encoding them, the JSON column in SQLite will contain garbled binary data that looks valid but produces no matches on lookup.

**Why it happens:**
`Ecto.UUID.dump/1` produces a 16-byte binary; `Ecto.UUID.load/1` converts it back to a string. If the export script reads rows via raw SQL (not through schemas), the binary is base64-encoded or written as a raw byte sequence into the JSON array, making all FK lookups fail silently.

**How to avoid:**
Always export UUID values through `Ecto.UUID.load!/1` before encoding to JSON:

```elixir
# In the data export script, convert each UUID in the array
linked_task_ids
|> Enum.map(fn
  <<_::128>> = bin -> Ecto.UUID.load!(bin)  # binary -> string
  str when is_binary(str) -> str             # already string
end)
|> Jason.encode!()
```

Verify with `sqlite3 lifeboard.db "SELECT hex(linked_task_ids) FROM goals LIMIT 1;"` — the result must be valid JSON text, not a blob.

**Warning signs:**
- Any column typed `{:array, :binary_id}` in migrations.
- After import, running `SELECT json_each.value FROM goals, json_each(linked_task_ids) LIMIT 5;` returns non-UUID-shaped values.
- Queries filtering on array members return 0 rows despite data being present.

**Phase to address:** Phase 3 (Data Export and Transform) — must be verified in the transform step before import begins.

---

### Pitfall 3: `fly.toml` Uses `release_command` for Migrations — This Has No Volume Access

**What goes wrong:**
The current `fly.toml` has:
```toml
[deploy]
  release_command = '/app/bin/migrate'
```
Fly.io runs `release_command` in a temporary ephemeral Machine that has no persistent volumes mounted. The SQLite database file lives at `/data/lifeboard.db` on the persistent volume — which is not accessible during the release command. The migration binary runs, finds no database file, either crashes or creates a temp file that is immediately discarded, and the deploy proceeds with an unmigrated database.

**Why it happens:**
`release_command` is correct for PostgreSQL (which is network-accessible from any Machine). It is fundamentally wrong for SQLite because the database is only accessible from the Machine that has the volume mounted.

**How to avoid:**
Remove the `release_command` from `fly.toml`. Instead, run migrations at application startup in `Application.start/2`:

```elixir
# lib/mega_planner/application.ex
def start(_type, _args) do
  MegaPlanner.Release.migrate()  # runs before children start
  children = [...]
  Supervisor.start_link(children, opts)
end
```

This guarantees the volume is mounted before migrations execute. The `MegaPlanner.Release` module (generated by `mix release`) already exists; call `migrate/0` at startup rather than in the release phase.

**Warning signs:**
- `fly.toml` has any entry under `[deploy]` → `release_command`.
- App deploys successfully but tables are missing or empty after deploy.
- Logs show migration binary running but no SQLite file path in the logs.

**Phase to address:** Phase 4 (Fly.io Volume and Deployment Configuration) — must be changed before any production deploy attempt.

---

### Pitfall 4: SQLite File Stored in Docker Image Layer Instead of Volume — Silent Full Data Wipe on Deploy

**What goes wrong:**
If `DATABASE_PATH` is not set to a path inside the mounted volume (e.g., `/data/lifeboard.db`), or if the volume mount is misconfigured, the SQLite file is written to the container's ephemeral filesystem. The app functions normally during the current session. On the next `fly deploy`, the container is replaced and all data is gone. There is no error — data loss is silent.

**Why it happens:**
SQLite is a file, not a network service. The path is configured via `DATABASE_PATH` or hardcoded in `config/runtime.exs`. If the path defaults to a relative path like `./lifeboard.db` or an absolute path not under the mount point, it writes to ephemeral storage. The Fly Machine filesystem is blank on every startup.

**How to avoid:**
1. Create the volume before first deploy: `fly volumes create lifeboard_data --size 5 --region iad`
2. Set `fly.toml`:
   ```toml
   [mounts]
     source = "lifeboard_data"
     destination = "/data"

   [env]
     DATABASE_PATH = "/data/lifeboard.db"
   ```
3. In `config/runtime.exs`:
   ```elixir
   database_path = System.get_env("DATABASE_PATH") ||
     raise "DATABASE_PATH environment variable not set"
   config :mega_planner, MegaPlanner.Repo, database: database_path
   ```
4. Verify volume is mounted: `fly ssh console -C "ls -la /data/"` after deploy.

**Warning signs:**
- No `[mounts]` section in `fly.toml`.
- `DATABASE_PATH` not in `[env]` section of `fly.toml`.
- `config/runtime.exs` uses a hardcoded path or falls back to a non-`/data` path.
- Data disappears after every deploy during testing.

**Phase to address:** Phase 4 (Fly.io Volume and Deployment Configuration) — foundational infrastructure change.

---

### Pitfall 5: `ilike/2` Used Extensively Throughout Application Code — Fails at Runtime Against SQLite

**What goes wrong:**
The codebase uses `ilike/2` in at least 30+ locations across `search.ex`, `inventory.ex`, `receipts.ex`, `goals.ex`, and `templates.ex`. Against SQLite, every one of these queries raises `(Ecto.QueryError) ilike is not supported by SQLite3` at runtime. Because these are runtime errors, there is no compile-time warning. Features that work in development (against PostgreSQL) silently break against SQLite.

**Why it happens:**
`ILIKE` is a PostgreSQL extension that does not exist in the SQL standard. SQLite's `LIKE` is case-insensitive for ASCII characters by default, making it the functional equivalent — but the Ecto DSL function names differ.

**How to avoid:**
Replace all `ilike(field, pattern)` with `like(field, pattern)`. SQLite's `LIKE` is case-insensitive by default (via `ecto_sqlite3`'s default `case_sensitive_like: false` setting). This is a safe drop-in replacement for ASCII text searches.

```elixir
# Before (PostgreSQL)
where: ilike(u.name, ^"%#{search}%")

# After (SQLite-compatible, also works on PostgreSQL for simple cases)
where: like(u.name, ^"%#{search}%")
```

For Unicode text (non-ASCII), `LIKE` in SQLite is case-sensitive for non-ASCII characters. If the data contains Unicode, use `fragment("LOWER(?) LIKE LOWER(?)", field, ^pattern)` as the safe cross-database approach — which the codebase already does in several places in `inventory.ex` and `receipts.ex`.

Run: `grep -rn "ilike" lib/` to find all occurrences. There are approximately 35+ calls to replace.

**Warning signs:**
- `grep -rn "ilike" lib/` returns any results.
- Search endpoints return `500` errors immediately after switching to `ecto_sqlite3`.
- Test suite passes with PostgreSQL but crashes against SQLite.

**Phase to address:** Phase 2 (Schema and Application Code Audit) — must be fixed before any SQLite testing.

---

### Pitfall 6: `:jsonb` Column Type Not Recognized by `ecto_sqlite3` — Migration Fails

**What goes wrong:**
Two columns in `20260101000017_create_user_preferences.exs` are declared as `:jsonb`:
```elixir
add :dashboard_widgets, :jsonb, default: "[]"
add :settings, :jsonb, default: "{}"
```
The `ecto_sqlite3` adapter does not recognize `:jsonb` as a valid column type. The migration will raise an error or silently create the column with an unrecognized affinity, causing all reads/writes to fail. The `:jsonb` type is PostgreSQL-specific.

**Why it happens:**
Developers use `:jsonb` explicitly in migrations (rather than `:map`) when they want JSONB-specific PostgreSQL behavior. The SQLite adapter only understands `:map` (stored as JSON text string) and its configured `:map_type` (`:string` or `:binary`).

**How to avoid:**
Replace all `:jsonb` column type declarations with `:map` in migrations:
```elixir
# Before
add :dashboard_widgets, :jsonb, default: "[]"
add :settings, :jsonb, default: "{}"

# After
add :dashboard_widgets, :map, default: %{}
add :settings, :map, default: %{}
```

Also update schema files to use `field :dashboard_widgets, :map` instead of any `:jsonb` type reference.

**Warning signs:**
- `grep -rn ":jsonb" priv/repo/migrations/` returns any results.
- Migration error mentioning unknown column type during `mix ecto.migrate`.

**Phase to address:** Phase 1 (Migration Audit and Rewrite).

---

### Pitfall 7: `{:array, :type}` Column Declarations Silently Drop Default Values

**What goes wrong:**
SQLite has no native array type. `ecto_sqlite3` serializes arrays as JSON text. Migration declarations like `add :tags, {:array, :string}, default: []` must be rewritten to `:text` with a JSON default. If rewritten incorrectly (e.g., keeping `default: []` instead of `default: "[]"`), the column gets created with `DEFAULT '[]'` which works, but the Ecto schema must declare the field with a custom type or the `EctoArrays` workaround — otherwise `Repo.all` returns raw JSON strings instead of lists.

**Why it happens:**
`ecto_sqlite3` handles `{:array, :string}` at the schema layer (deserialization from JSON text) but the migration layer needs a plain `:text` column. The schema field declaration must tell Ecto how to deserialize the stored JSON string back into an Elixir list.

**How to avoid:**
In migrations, replace `{:array, :type}` with `:text`:
```elixir
# Before
add :tags, {:array, :string}, default: []
add :days_of_week, {:array, :integer}

# After
add :tags, :text, default: "[]"
add :days_of_week, :text
```

In schema files, keep `field :tags, {:array, :string}` — `ecto_sqlite3` handles the JSON deserialization automatically when the underlying column is `:text`. Do not change the schema field types; only the migration column types.

Verify by checking that `Repo.get(SomeSchema, id).tags` returns a list, not a string, after migration.

**Warning signs:**
- Ecto queries return `"[\"item1\",\"item2\"]"` (a string) instead of `["item1", "item2"]` (a list).
- `cast({:array, :string})` in changesets raises a type mismatch error.
- Any `{:array, ...}` in migration files after switching to `ecto_sqlite3`.

**Phase to address:** Phase 1 (Migration Audit and Rewrite) + Phase 2 (Schema Audit).

---

### Pitfall 8: `schema_migrations` Table Missing in Fresh SQLite DB — `mix ecto.migrate` Fails or Reruns All Migrations

**What goes wrong:**
When starting with a fresh SQLite database (production or dev), `mix ecto.migrate` must create the `schema_migrations` table and then run all pending migrations in order. If the migration history from PostgreSQL is not transferred to SQLite's `schema_migrations` table before running migrations against existing data, Ecto will attempt to re-run all migrations against a database that already has the tables, causing `(Exqlite.Error) table X already exists` errors.

Conversely, if the `schema_migrations` table is pre-populated (to skip re-running migrations) but the SQLite schema was created via a direct import of the PostgreSQL schema dump, there may be column type mismatches that go undetected until runtime.

**Why it happens:**
The migration path is: export PostgreSQL data → create fresh SQLite schema via `mix ecto.migrate` → import data. If these steps are done out of order, or if the schema is imported from pg_dump instead of re-created by running Elixir migrations, the `schema_migrations` table state diverges from reality.

**How to avoid:**
Follow this exact sequence for the production cutover:
1. Run `mix ecto.create` against fresh SQLite database.
2. Run `mix ecto.migrate` (which creates `schema_migrations` and runs all 20+ migrations in SQLite syntax).
3. Only after step 2 succeeds, import the transformed production data via Elixir scripts.
4. Verify record counts match PostgreSQL.

Do NOT import data before creating the schema. Do NOT copy the PostgreSQL `schema_migrations` table directly; let Ecto recreate it by running the migrations.

**Warning signs:**
- `(Exqlite.Error) table already exists` errors during `mix ecto.migrate`.
- `schema_migrations` table exists in SQLite but was populated by copying from PostgreSQL rather than by running migrations.
- Migration count in SQLite's `schema_migrations` differs from PostgreSQL's.

**Phase to address:** Phase 3 (Data Export and Import) and Phase 5 (Cutover).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep existing migrations as-is, create one "fixup" migration for SQLite | Avoids rewriting 20+ migration files | Old migrations still fail if re-run from scratch (e.g., new dev environment) | Never — breaks `mix ecto.reset` and CI from scratch |
| Use `fragment()` with PostgreSQL JSON operators (`->`, `->>`) on `:map` fields | Works against PostgreSQL | Silently breaks when adapter switches; runtime errors in production | Never for code that must work against SQLite |
| Set `pool_size: 5` (default) in production SQLite config | Familiar from PostgreSQL setup | Write contention causes `SQLITE_BUSY` errors under any concurrent load | Never — use `pool_size: 1` with `busy_timeout` |
| Copy `schema_migrations` from PostgreSQL instead of re-running migrations | Saves migration run time | Schema may diverge silently; first new migration may fail unexpectedly | Never for a clean migration |
| Run migrations with `FK pragma off` and never re-enable | Simpler migration logic | Application data can violate FK constraints silently forever | Never — enable FKs after migrations complete |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Fly.io volumes + SQLite | Forgetting to create the volume before first deploy — app starts with ephemeral DB | Run `fly volumes create` before `fly deploy`; confirm with `fly volumes list` |
| Fly.io `release_command` | Using `release_command` for `mix ecto.migrate` — has no volume access | Run migrations in `Application.start/2`; remove `release_command` from `fly.toml` |
| Fly.io WAL file | Moving only the `.db` file to volume; leaving `.db-wal` and `.db-shm` behind | Copy all three files (`*.db`, `*.db-wal`, `*.db-shm`) together; they are a unit |
| `ecto_sqlite3` + ExUnit async tests | Keeping `async: true` on tests that hit the database | Set `async: false` on all database tests; SQLite is single-writer, sandbox wraps in transaction |
| `ecto_sqlite3` + Ecto Sandbox shared mode | Tests using `Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})` with `async: true` | Remove `async: true` from test modules; keep shared mode but force synchronous execution |
| `Ecto.Changeset.foreign_key_constraint/3` | Expecting named constraint errors from SQLite | SQLite returns unnamed FK violations; `foreign_key_constraint/3` will not match — use application-level validation instead |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Default `pool_size: 10` with SQLite | `(Exqlite.Error) Database busy` or `SQLITE_BUSY` on writes under any concurrent load | Set `pool_size: 1` for write repo; use `busy_timeout: 5000` | Immediately under any concurrent writes (even 2 concurrent requests) |
| WAL mode not configured | WAL defaults are set by `ecto_sqlite3` but confirm `journal_mode: :wal` is explicit in config | Add explicit WAL config to `runtime.exs` | Concurrent read + write operations cause full-table locks |
| No `busy_timeout` set | Write operations fail immediately with `SQLITE_BUSY` instead of queuing | Set `busy_timeout: 5000` in repo config | Any time two requests write simultaneously |
| `PRAGMA foreign_keys=OFF` forgotten | FK violations inserted silently during data import; discovered at read time | Set `foreign_keys: :on` in `ecto_sqlite3` config (it is the default); verify explicitly | At query time when JOIN produces missing rows |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| SQLite file stored at a predictable path accessible to the web process | If path traversal vulnerability exists, DB file is directly readable | Store at `/data/lifeboard.db`, ensure the web process runs as a non-root user, and the volume is not web-accessible |
| No backup before production cutover | Single point of failure — any mistake during import destroys all data | `fly ssh sftp get /data/lifeboard.db ./backup.db` before and after import; keep PostgreSQL running until verified |
| Not verifying record counts post-migration | Silent data loss passes undetected | Compare `SELECT COUNT(*) FROM table` for every table in PostgreSQL vs. SQLite after import |

---

## "Looks Done But Isn't" Checklist

- [ ] **Migration rewrite:** All 20+ migration files run successfully from scratch via `mix ecto.reset` against a local SQLite file — verify by deleting the local `.db` file and running `mix ecto.create && mix ecto.migrate`.
- [ ] **`ilike` removal:** `grep -rn "ilike" lib/` returns zero results — search is the most-used feature and is completely broken until this is done.
- [ ] **`:jsonb` removal:** `grep -rn ":jsonb" priv/repo/migrations/` returns zero results.
- [ ] **`gen_random_uuid` removal:** `grep -rn "gen_random_uuid" priv/repo/migrations/` returns zero results.
- [ ] **`release_command` removed:** `fly.toml` has no `[deploy]` section with `release_command`.
- [ ] **Volume confirmed:** `fly volumes list` shows a volume attached to the app; `fly ssh console -C "ls -la /data/"` shows the `.db` file.
- [ ] **`async: false` on DB tests:** `grep -rn "async: true" test/` returns zero results for modules that use `Ecto.Adapters.SQL.Sandbox`.
- [ ] **Record count verification:** Every table's row count in SQLite matches PostgreSQL post-import — run a comparison script before cutover.
- [ ] **UUID arrays verified:** Spot-check `goals.linked_task_ids`, `habits.linked_inventory_ids`, `brands.default_tags` — values must be valid UUID strings after import, not binary data.
- [ ] **WAL + pool config in runtime.exs:** `pool_size: 1`, `journal_mode: :wal`, `busy_timeout: 5000` present in production config.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Data wiped due to ephemeral storage | HIGH | Restore from PostgreSQL (if still running) or pg_dump backup; re-import |
| UUID binary corruption in array columns | HIGH | Re-run export and transform with corrected UUID serialization; re-import |
| `ilike` crashes in production | MEDIUM | Quick fix: deploy `ilike` → `like` replacement; takes ~30 minutes of work |
| Migration fails mid-run (FK constraint or PL/pgSQL) | MEDIUM | Fix failing migration; run `mix ecto.migrate` again (partial migrations are rolled back) |
| `release_command` ran with no volume | LOW | Remove `release_command` from `fly.toml`; redeploy; migrations will run at startup |
| `schema_migrations` out of sync | MEDIUM | Manually insert/delete version rows in `schema_migrations` to match actual schema state; then run pending migrations |
| `async: true` tests deadlock CI | LOW | Add `async: false` to test modules; rerun CI |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| PL/pgSQL block in migration 13 | Phase 1: Migration Rewrite | `mix ecto.reset` completes without errors on SQLite |
| `:jsonb` column type | Phase 1: Migration Rewrite | `mix ecto.migrate` completes; no `:jsonb` in codebase |
| `{:array, type}` migration declarations | Phase 1: Migration Rewrite | `Repo.get(Schema, id).field` returns a list, not a string |
| `gen_random_uuid()` in raw SQL | Phase 1: Migration Rewrite | `grep -rn "gen_random_uuid"` returns zero results |
| `ilike/2` in application code | Phase 2: Application Code Audit | `grep -rn "ilike"` returns zero results; search endpoints return 200 |
| Fragment using PostgreSQL JSON operators | Phase 2: Application Code Audit | All queries tested against local SQLite; no Ecto.QueryError |
| UUID binary corruption in array export | Phase 3: Data Export/Transform | Spot-check query on UUID array columns returns valid UUID strings |
| NULL vs. empty string in export | Phase 3: Data Export/Transform | `SELECT COUNT(*) WHERE field IS NULL` vs. `WHERE field = ''` matches expected counts |
| `schema_migrations` ordering | Phase 3: Import Sequence | Fresh `mix ecto.migrate` completes without "table already exists" errors |
| `release_command` volume access | Phase 4: Fly.io Config | Migrations log shows "Applied N migrations" on first deploy startup |
| Ephemeral storage (no volume) | Phase 4: Fly.io Config | Data persists across two consecutive `fly deploy` cycles |
| WAL file not co-located with DB | Phase 4: Fly.io Config | `ls /data/*.db*` shows all three SQLite files together |
| `async: true` DB tests | Phase 2: Application Code Audit | `mix test` completes without `(Exqlite.Error) Database busy` |
| Pool size too high | Phase 4: Fly.io Config | No `SQLITE_BUSY` errors in logs under simulated concurrent load |

---

## Sources

- [ecto_sqlite3 official adapter docs — limitations, UUID config, async testing](https://hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html)
- [ecto_sqlite3 GitHub issue #70 — binary_id_type config and UUID storage confusion](https://github.com/elixir-sqlite/ecto_sqlite3/issues/70)
- [ecto_sqlite3 GitHub issue #51 — UUID handling behavior](https://github.com/elixir-sqlite/ecto_sqlite3/issues/51)
- [ecto_sqlite3 GitHub issue #99 — concurrent sandbox / BEGIN CONCURRENT not supported](https://github.com/elixir-sqlite/ecto_sqlite3/issues/99)
- [Elixir Forum — PRAGMA foreign_keys=OFF inside transactions is a no-op](https://elixirforum.com/t/how-to-set-pragma-foreign-keys-off-in-ecto-migration/64849)
- [Elixir Forum — Ecto not finding constraints when inserting in SQLite](https://elixirforum.com/t/ecto-not-finding-my-constraints-when-inserting-in-sqlite/68425)
- [Fly.io official SQLite3 guide for Elixir/Phoenix](https://fly.io/docs/elixir/advanced-guides/sqlite3/)
- [Fly.io community — sqlite lost after deployment](https://community.fly.io/t/sqlite-lost-after-deployment/9852)
- [Fly.io community — SQLite file in Volume lost data on deploy](https://community.fly.io/t/sqlite-file-in-volume-lost-data-on-deploy/6126)
- [Fly.io volumes overview — ephemeral storage warning](https://fly.io/docs/volumes/overview/)
- [Wawandco blog — real-world PostgreSQL to SQLite on Fly.io migration](https://wawand.co/blog/posts/tech-tales-fly-sqlite-and-postgres/)
- [Elixir Forum — SQLite in production pool size and WAL](https://elixirforum.com/t/sqlite-in-production/53295)
- [Phoenix + SQLite deployment tips gist by mcrumm](https://gist.github.com/mcrumm/98059439c673be7e0484589162a54a01)
- [SQLite case-insensitive LIKE vs PostgreSQL ILIKE](https://elixirforum.com/t/how-to-perform-a-query-with-like-using-sqlite-through-ecto/74093)
- [ecto_sql GitHub issue #62 — UUID dump/load across adapters](https://github.com/elixir-ecto/ecto_sql/issues/62)
- [SQLite JSON functions reference](https://sqlite.org/json1.html)

---
*Pitfalls research for: Phoenix/Ecto PostgreSQL-to-SQLite migration on Fly.io*
*Researched: 2026-03-07*
