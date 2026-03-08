# Feature Research: PostgreSQL → SQLite Migration

**Domain:** PostgreSQL-specific feature compatibility with SQLite via ecto_sqlite3
**Researched:** 2026-03-07
**Confidence:** HIGH (verified against ecto_sqlite3 v0.22.0 official docs and source code)

---

## Overview

This document maps every PostgreSQL-specific feature used in the Lifeboard codebase to its SQLite/ecto_sqlite3 equivalent. Each finding is classified as a table stake (must replicate for the app to function), a workaround (how to replicate it), or a true limitation (what cannot be replicated and what to do instead).

---

## Table Stakes (Must Replicate for App to Function)

These are features the app actively relies on. If any of these are not correctly handled, the app will crash, produce corrupt data, or silently lose information.

| Feature | Where Used | Migration Type | Schema Type | Why It Must Work |
|---------|------------|----------------|-------------|------------------|
| `{:array, :string}` | `task_templates.default_steps`, `budget_sources.tags`, `user_preferences.nav_order` | `{:array, :string}` | `{:array, :string}` | Template steps, nav preferences, and legacy budget tags are stored and returned as lists |
| `{:array, :integer}` | `habits.days_of_week` | `{:array, :integer}` | `{:array, :integer}` | Weekly habit scheduling depends on this integer list |
| `{:array, :binary_id}` | `goals.linked_task_ids`, `habit_inventories.linked_inventory_ids`, `brands.default_tags` | `{:array, :binary_id}` | `{:array, :binary_id}` | Goal-task links, habit group inventory links, and brand tag defaults are stored as UUID arrays |
| `:jsonb` | `user_preferences.dashboard_widgets`, `user_preferences.settings` | `:jsonb` | `{:array, :map}` / `:map` | Dashboard layout and user settings must survive round-trips through the database |
| `:map` | `tasks.recurrence_rule`, `budget_sources.recurrence_rule`, `notifications.data`, `notification_preferences.push_subscription`, `inventory_sheets.columns`, `inventory_items.custom_fields`, `receipts/format_corrections.preference_notes` | `:map` | `:map` | Structured freeform data stored and retrieved as Elixir maps |
| `:binary_id` primary keys | All 30+ tables | `:binary_id, primary_key: true` | `@primary_key {:id, :binary_id, autogenerate: true}` | Every record uses UUID PKs; must preserve existing UUID values during data migration |
| `gen_random_uuid()` in raw SQL | Migration `20260101000013` (PL/pgSQL DO block) | PostgreSQL-only function | N/A | Used to generate household UUIDs inline during a data migration |

---

## Feature-by-Feature Workarounds

### 1. `{:array, :string}` columns

**PostgreSQL behavior:** Native array type. Individual elements indexable by SQL.

**SQLite behavior with ecto_sqlite3:** The `{:array, :string}` type is fully supported. ecto_sqlite3 serializes the array as a JSON string (TEXT column) by default. On read, it JSON-decodes back to an Elixir list of strings. No schema changes are needed.

**Migration syntax — no change needed:**
```elixir
# This works in ecto_sqlite3 as-is
add :default_steps, {:array, :string}, default: []
add :nav_order, {:array, :string}, default: []
add :tags, {:array, :string}, default: []
```

**Schema syntax — no change needed:**
```elixir
field :default_steps, {:array, :string}, default: []
field :nav_order, {:array, :string}, default: []
```

**Behavior change:** None for application code. The value stored in SQLite is a JSON text blob (`["step1","step2"]`), not a PostgreSQL native array. Ecto handles the encoding/decoding transparently.

**Confidence:** HIGH — verified against ecto_sqlite3 v0.22.0 docs and source.

---

### 2. `{:array, :integer}` columns

**PostgreSQL behavior:** Native integer array.

**SQLite behavior with ecto_sqlite3:** Same as `{:array, :string}` — serialized as JSON text. Integer values are preserved correctly through JSON round-trips.

**Migration syntax — no change needed:**
```elixir
add :days_of_week, {:array, :integer}
```

**Schema syntax — no change needed:**
```elixir
field :days_of_week, {:array, :integer}
```

**Behavior change:** None. The `validate_days_of_week/1` changeset function in `habit.ex` operates on the Elixir list after Ecto decodes it, so it continues to work correctly.

**Confidence:** HIGH.

---

### 3. `{:array, :binary_id}` columns

**PostgreSQL behavior:** Native UUID array; each element stored as a proper UUID.

**SQLite behavior with ecto_sqlite3:** This is the trickiest array type. ecto_sqlite3 serializes the whole array as JSON, but when reading back, the per-element `:binary_id` type coercion is NOT applied — only JSON decoding runs. This means UUIDs come back as plain strings, which is actually correct behavior since `binary_id_type` defaults to `:string` (TEXT storage for UUIDs).

**The key insight:** With `binary_id_type: :string` (the default), UUIDs are stored as plain UUID strings (e.g., `"550e8400-e29b-41d4-a716-446655440000"`). An array of them serializes to `["uuid1","uuid2"]` in JSON — which reads back correctly as a list of strings in Elixir. The schema type `{:array, :binary_id}` will still work.

**Migration syntax — no change needed:**
```elixir
add :linked_task_ids, {:array, :binary_id}, default: []
add :linked_inventory_ids, {:array, :binary_id}, default: []
add :default_tags, {:array, :binary_id}, default: []
```

**Schema syntax — no change needed:**
```elixir
field :linked_task_ids, {:array, :binary_id}, default: []
field :linked_inventory_ids, {:array, :binary_id}, default: []
field :default_tags, {:array, :binary_id}
```

**Alternative if issues arise:** Cast to `{:array, :string}` in the schema and validate UUID format in changesets. This sidesteps the binary_id sub-type coercion question entirely.
```elixir
# Fallback if {:array, :binary_id} proves unreliable in ecto_sqlite3
field :linked_task_ids, {:array, :string}, default: []
```

**Behavior change:** UUID array values become a JSON text blob in SQLite. Application behavior is unchanged since the app only reads/writes these as lists, never queries inside them with SQL array operators.

**Data migration note:** PostgreSQL exports UUIDs in standard string format. The JSON-serialized array will look like `["uuid-string-1","uuid-string-2"]` in SQLite — which is the correct format ecto_sqlite3 expects on read.

**Confidence:** MEDIUM — the `{:array, :binary_id}` sub-type coercion gap is documented in the ecto_sqlite3 source; however, since the app uses `binary_id_type: :string` (default), UUIDs are already strings and JSON round-trips are clean.

---

### 4. `:jsonb` columns (`dashboard_widgets`, `settings`)

**PostgreSQL behavior:** Native JSONB binary format; supports JSON operators, indexing, containment queries.

**SQLite behavior with ecto_sqlite3:** ecto_sqlite3 does not support the `:jsonb` migration type. The migration must be changed to use `:map` for object fields or `{:array, :map}` for array-of-objects fields.

**Migration change required — this is the one migration type that must be rewritten:**

```elixir
# BEFORE (PostgreSQL)
add :dashboard_widgets, :jsonb, default: "[]"
add :settings, :jsonb, default: "{}"

# AFTER (SQLite-compatible)
add :dashboard_widgets, {:array, :map}, default: []
add :settings, :map, default: %{}
```

**Schema type — check alignment with migration:**
```elixir
# user_preferences.ex currently declares:
field :dashboard_widgets, {:array, :map}, default: []   # already correct
field :settings, :map, default: %{}                     # already correct
```

The schema already uses `{:array, :map}` and `:map` — only the migration needs updating from `:jsonb` to the Ecto-portable equivalents.

**Behavior change:** No JSONB operators (`@>`, `?`, `#>>`) exist in this codebase — the schema is used only for read/write of the entire field. No query behavior changes.

**Confidence:** HIGH — ecto_sqlite3 docs explicitly state `:map_type` defaults to `:string` (JSON text) and `{:array, :map}` is the standard Ecto pattern for arrays of maps.

---

### 5. `:map` columns

**PostgreSQL behavior:** Stored as JSONB by the `postgrex` adapter.

**SQLite behavior with ecto_sqlite3:** Stored as JSON text (TEXT column). ecto_sqlite3 JSON-encodes the Elixir map on write and JSON-decodes on read. No schema or migration changes are required — `:map` is a portable Ecto type.

**Migration syntax — no change needed:**
```elixir
add :recurrence_rule, :map
add :push_subscription, :map
add :data, :map, default: %{}
add :columns, :map, default: %{}
add :custom_fields, :map, default: %{}
add :preference_notes, :map, default: %{}
```

**Schema syntax — no change needed:**
```elixir
field :recurrence_rule, :map
field :push_subscription, :map
field :data, :map, default: %{}
```

**Behavior change:** None for application code. Map data round-trips correctly through JSON. The `push_subscription` map (a WebPush subscription object) will serialize/deserialize correctly.

**Confidence:** HIGH.

---

### 6. UUID primary keys (`:binary_id`)

**PostgreSQL behavior:** UUIDs generated by `gen_random_uuid()` or by Ecto's `autogenerate: true`, stored as native UUID type (16 bytes).

**SQLite behavior with ecto_sqlite3:** UUIDs are generated entirely by Ecto in the application layer (not the database). With `binary_id_type: :string` (the default), they are stored as TEXT in the format `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"` (36 chars). The `@primary_key {:id, :binary_id, autogenerate: true}` pattern works identically to PostgreSQL — Ecto generates the UUID before inserting.

**Migration syntax — no change needed:**
```elixir
create table(:users, primary_key: false) do
  add :id, :binary_id, primary_key: true
  ...
end
```

**Schema syntax — no change needed:**
```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
```

**Behavior change:** UUID generation moves entirely to the application layer (it was already there for most tables via `autogenerate: true`). The database never generates UUIDs. This is already how the schemas are configured.

**Data migration note:** Existing UUID values from PostgreSQL are plain UUID strings. SQLite stores them as TEXT strings. No encoding transformation is needed during import — they transfer directly.

**Confidence:** HIGH — confirmed by ecto_sqlite3 official docs and issue #51 discussion.

---

### 7. `gen_random_uuid()` in raw SQL migration

**File:** `20260101000013_add_household_id_to_data_tables.exs`

**PostgreSQL behavior:** A PL/pgSQL `DO $$ DECLARE ... END $$;` anonymous block loops over users, calls `gen_random_uuid()` to create a UUID, inserts a household record, and updates the user's `household_id`. This is PostgreSQL-only syntax.

**The problem has two parts:**
1. `DO $$ DECLARE ... END $$;` — PL/pgSQL anonymous block, not supported in SQLite
2. `gen_random_uuid()` — PostgreSQL function, does not exist in SQLite

**SQLite workaround:** Replace the entire PL/pgSQL block with an Elixir function in the migration using `repo().query!/2` or direct Ecto calls. Since this migration runs during `mix ecto.migrate`, Elixir is available.

```elixir
def up do
  # Replace the DO $$ block with Elixir logic:
  execute "INSERT INTO households (id, name, inserted_at, updated_at)
           SELECT lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' ||
                  substr(lower(hex(randomblob(2))),2) || '-' ||
                  substr('89ab',abs(random()) % 4 + 1, 1) ||
                  substr(lower(hex(randomblob(2))),2) || '-' ||
                  lower(hex(randomblob(6))),
                  COALESCE(name, email) || '''s Household',
                  datetime('now'), datetime('now')
           FROM users WHERE household_id IS NULL"
  ...
end
```

**Recommended approach — use Elixir directly in the migration (cleaner):**
```elixir
def up do
  # Fetch users without households
  users = repo().query!(
    "SELECT id, name, email FROM users WHERE household_id IS NULL"
  ).rows

  Enum.each(users, fn [id, name, email] ->
    household_id = Ecto.UUID.generate()
    household_name = "#{name || email}'s Household"
    now = NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601()

    repo().query!(
      "INSERT INTO households (id, name, inserted_at, updated_at) VALUES (?, ?, ?, ?)",
      [household_id, household_name, now, now]
    )
    repo().query!(
      "UPDATE users SET household_id = ? WHERE id = ?",
      [household_id, id]
    )
  end)

  # Continue with ALTER TABLE statements as before...
end
```

**Behavior change:** Functionally identical. `Ecto.UUID.generate/0` produces RFC 4122 v4 UUIDs, same format as `gen_random_uuid()`.

**Confidence:** HIGH — `Ecto.UUID.generate/0` is well-documented; SQLite `randomblob()` UUID generation is a common pattern if Elixir-in-migration isn't preferred.

---

### 8. SQL `fragment/1` functions (LOWER, UPPER, TRIM, COALESCE)

**Where used:** Extensively throughout `receipts.ex`, `inventory.ex`, and `receipt_parser.ex` for case-insensitive comparisons.

**PostgreSQL behavior:** `LOWER()`, `UPPER()`, `TRIM()`, `COALESCE()` are standard SQL functions.

**SQLite behavior:** All four are native SQLite core scalar functions — no changes required. The `fragment/1` calls work identically in ecto_sqlite3.

```elixir
# These all work unchanged in SQLite:
fragment("LOWER(?) = LOWER(?)", s.name, ^name)
fragment("UPPER(?) = UPPER(?)", tim.indicator, ^indicator)
fragment("LOWER(TRIM(COALESCE(?, ?)))", sli.name, inv.name)
```

**Behavior change:** None.

**Confidence:** HIGH — SQLite official documentation confirms all four functions are built-in core scalar functions.

---

### 9. Partial index with WHERE clause

**File:** `20260101000004_create_inventory.exs`

```elixir
create unique_index(:shopping_list_items, [:user_id, :inventory_item_id],
  where: "purchased = false")
```

**PostgreSQL behavior:** Supported natively.

**SQLite behavior:** SQLite supports partial indexes natively since version 3.8.0. The `:where` option in `Ecto.Migration.create/1` is documented for PostgreSQL but the underlying SQLite `CREATE INDEX ... WHERE ...` syntax is valid.

**Recommended approach:** Use a raw `execute` to guarantee the partial index is created correctly without relying on adapter translation:

```elixir
# Replace the Ecto partial index with explicit SQL
execute """
CREATE UNIQUE INDEX IF NOT EXISTS shopping_list_items_user_id_inventory_item_id_index
ON shopping_list_items (user_id, inventory_item_id)
WHERE purchased = 0
"""
```

Note: SQLite represents booleans as `0`/`1` integers — use `0` not `false` in the WHERE clause of raw SQL.

**Behavior change:** Same functional behavior (prevents duplicate active shopping list entries). Syntax difference in migration only.

**Confidence:** MEDIUM — SQLite supports partial indexes natively; the issue is whether ecto_sqlite3's migration runner passes the `:where` option through correctly. Raw SQL is safer.

---

## What Truly Cannot Be Replicated

| PostgreSQL Feature | Status | Impact | What To Do Instead |
|-------------------|--------|--------|-------------------|
| JSONB operators (`@>`, `?`, `#>>`, `&&`) | Not available in SQLite | NONE — not used anywhere in this codebase | N/A |
| `ANY(array)` SQL operator | Not available in SQLite | NONE — not used in any Ecto query | N/A |
| `array_agg()` aggregate | Not available in SQLite | NONE — not used in any Ecto query | N/A |
| Named foreign key constraints in changeset errors | Not available | LOW — `foreign_key_constraint/3` in changesets will not produce field-level errors; will raise `Ecto.ConstraintError` instead | Validate referential integrity in changeset with `validate_change` before insert; or rescue `Ecto.ConstraintError` |
| PL/pgSQL anonymous blocks (`DO $$`) | Not available in SQLite | ONE migration must be rewritten | Use Elixir in the migration body with `repo().query!/2` |
| `gen_random_uuid()` SQL function | Not available in SQLite | ONE migration must be rewritten | Use `Ecto.UUID.generate()` in Elixir |
| Async test sandbox | Not supported by ecto_sqlite3 | Affects test suite only | Use `ownership_timeout` and synchronous test mode |
| Schemaless query type coercion | Partial — ecto_sqlite3 relies on schema | LOW — no schemaless queries appear in this codebase | Ensure all queries go through named schemas |

---

## Anti-Features (Approaches That Seem Reasonable But Will Cause Problems)

| Approach | Why Problematic | What To Do Instead |
|----------|-----------------|-------------------|
| Using `:binary` for `binary_id_type` | Changes UUID storage from TEXT to BLOB; existing UUID strings from PostgreSQL will not match binary-encoded UUIDs; breaks referential integrity during import | Keep `binary_id_type: :string` (the default); store UUIDs as plain strings |
| Using `array_type: :binary` (JSONB blobs) | Complicates data migration from PostgreSQL; JSONB binary format is SQLite-specific; exported data would be binary blobs | Keep `array_type: :string` (the default); JSON text is human-readable and directly importable |
| Using `map_type: :binary` (JSONB blobs) | Same problem as `array_type: :binary` | Keep `map_type: :string` |
| Reusing the existing `pg_dump` output directly as SQLite import | PostgreSQL dump format is incompatible with SQLite; UUID handling, JSONB format, array format, and PL/pgSQL all differ | Use an Elixir export script that reads via Ecto and writes SQLite-compatible INSERT statements |
| Relying on `foreign_key_constraint/3` in changesets for SQLite | SQLite does not surface constraint names — changeset error mapping fails silently and raises `Ecto.ConstraintError` | Pre-validate that referenced records exist using Ecto queries in `validate_change/3` |

---

## Feature Dependencies (Migration Order)

```
[Array/Map type config in config.exs]
    └──must exist before──> [Any schema reads/writes succeed]

[gen_random_uuid migration rewrite (migration 13)]
    └──must be done before──> [mix ecto.migrate runs against SQLite]

[:jsonb migration rewrite (user_preferences)]
    └──must be done before──> [dashboard and settings data migrates correctly]

[Data export from PostgreSQL]
    └──must complete before──> [SQLite import begins]

[SQLite import with UUID string format]
    └──depends on──> [binary_id_type: :string config being in place]
```

---

## MVP Definition

### Launch With (Migration Complete = v1)

- [x] `{:array, :string}` — works as-is, no changes
- [x] `{:array, :integer}` — works as-is, no changes
- [x] `{:array, :binary_id}` — works as-is with string binary_id_type
- [x] `:map` columns — works as-is, no changes
- [ ] `:jsonb` migration syntax — must be rewritten to `:map` / `{:array, :map}` in user_preferences migration
- [ ] `gen_random_uuid()` DO block — must be rewritten to Elixir in migration 13
- [ ] Partial index WHERE clause — rewrite to raw SQL `execute` for safety
- [ ] `foreign_key_constraint/3` — audit and replace with pre-validation in changesets if strict error handling is needed
- [x] `LOWER()`, `UPPER()`, `TRIM()`, `COALESCE()` fragments — work identically in SQLite

### Minimal Config Required in `config.exs`

```elixir
config :mega_planner, MegaPlanner.Repo,
  adapter: Ecto.Adapters.SQLite3,
  database: System.get_env("DATABASE_PATH", "/data/lifeboard.db")

# Keep defaults (string storage) for clean data migration
# config :ecto_sqlite3, binary_id_type: :string   # already the default
# config :ecto_sqlite3, array_type: :string        # already the default
# config :ecto_sqlite3, map_type: :string          # already the default
```

### Add After Migration Verified (v1.x)

- [ ] Review `foreign_key_constraint/3` calls across all changesets — decide whether to add pre-validation or leave as raise behavior
- [ ] Async test configuration — update test helpers for synchronous sandbox

---

## Complete Change Inventory

| File | Change Type | What Changes |
|------|-------------|-------------|
| `server/mix.exs` | Dependency swap | Remove `{:postgrex, ...}`, add `{:ecto_sqlite3, "~> 0.22"}` |
| `config/dev.exs` | Config rewrite | Replace PostgreSQL adapter config with SQLite3 adapter |
| `config/prod.exs` / `runtime.exs` | Config rewrite | Replace `DATABASE_URL` PostgreSQL config with SQLite file path |
| `priv/repo/migrations/20260101000013_add_household_id_to_data_tables.exs` | Migration rewrite | Replace `DO $$ DECLARE ... gen_random_uuid() ... END $$;` with Elixir repo calls |
| `priv/repo/migrations/20260101000017_create_user_preferences.exs` | Migration rewrite | Change `:jsonb` to `{:array, :map}` for `dashboard_widgets` and `:map` for `settings` |
| `priv/repo/migrations/20260101000004_create_inventory.exs` | Migration rewrite | Replace partial index Ecto DSL with `execute` raw SQL using `WHERE purchased = 0` |
| All other migrations | No change | `{:array, :string}`, `{:array, :integer}`, `{:array, :binary_id}`, `:map`, `:binary_id` are all supported as-is |
| All schema `.ex` files | No change | Schema field declarations are portable Ecto types; no changes needed |
| All context `.ex` files | No change | `fragment/1` calls use SQLite-compatible functions |

---

## Sources

- [Ecto.Adapters.SQLite3 — ecto_sqlite3 v0.22.0 (official docs)](https://hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html)
- [GitHub: elixir-sqlite/ecto_sqlite3](https://github.com/elixir-sqlite/ecto_sqlite3)
- [ecto_sqlite3 data_type.ex — array/map column type resolution](https://github.com/elixir-sqlite/ecto_sqlite3/blob/main/lib/ecto/adapters/sqlite3/data_type.ex)
- [ecto_sqlite3 Issue #51: Handling of UUIDs](https://github.com/elixir-sqlite/ecto_sqlite3/issues/51)
- [ecto_sqlite3 Issue #42: foreign_key_constraint support](https://github.com/elixir-sqlite/ecto_sqlite3/issues/42)
- [ecto_sqlite3 Issue #70: binary_id columns and binary_id_type config](https://github.com/elixir-sqlite/ecto_sqlite3/issues/70)
- [Fly.io SQLite3 guide for Elixir/Phoenix](https://fly.io/docs/elixir/advanced-guides/sqlite3/)
- [SQLite core scalar functions (LOWER, UPPER, TRIM, COALESCE)](https://sqlite.org/lang_corefunc.html)
- [SQLite partial index documentation](https://www.sqlite.org/partialindex.html)
- [Ecto.UUID — Ecto v3.13.5](https://hexdocs.pm/ecto/Ecto.UUID.html)
- [Why Ecto's Way of Storing Embedded Lists of Maps Makes Querying Hard — Thoughtbot](https://thoughtbot.com/blog/why-ecto-s-way-of-storing-embedded-lists-of-maps-makes-querying-hard)

---

*Feature research for: PostgreSQL → SQLite migration (Lifeboard)*
*Researched: 2026-03-07*
