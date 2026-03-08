# Phase 2: Migration Rewrites - Research

**Researched:** 2026-03-07
**Domain:** Elixir/Ecto migrations — PostgreSQL-to-SQLite compatibility rewrites
**Confidence:** HIGH (all migration files read directly from codebase; SQLite and ecto_sqlite3 behavior verified against official docs and hexdocs)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MIGR-01 | Rewrite migration `20260101000013` — replace the PL/pgSQL `DO $$ DECLARE ... gen_random_uuid() ... END $$;` block with Elixir using `repo().query!/2` and `Ecto.UUID.generate/0` | Pattern documented; `repo()` helper confirmed available in migrations; `Ecto.UUID.generate/0` confirmed API |
| MIGR-02 | Rewrite migration `20260101000017` — change `:jsonb` to `{:array, :map}` for `dashboard_widgets` and `:map` for `settings` | ecto_sqlite3 confirmed: `:jsonb` is not a recognized type; `:map` serializes as JSON text; `{:array, :map}` for arrays |
| MIGR-03 | Rewrite the partial unique index in the inventory migration — replace Ecto DSL `:where` option with a raw `execute` SQL statement using `WHERE purchased = 0` | CRITICAL FINDING: `where:` option IS supported by ecto_sqlite3/SQLite at DDL level; HOWEVER `purchased = false` must become `purchased = 0` in raw SQL since SQLite stores booleans as integers |
| MIGR-04 | Run `mix ecto.migrate` against a fresh SQLite database and confirm all migrations complete without errors | Scope confirmed; test command: `mix ecto.reset` from `server/` directory |
</phase_requirements>

---

## Summary

Phase 2 rewrites exactly three PostgreSQL-specific constructs in the migration files, then verifies clean execution. The codebase audit reveals the scope is slightly broader than the requirements initially implied: the `:where` option for partial indexes appears in **multiple** migrations (not just the inventory migration), and the `UPDATE ... FROM` syntax in the last migration needs verification.

The three targeted changes are: (1) replace the PL/pgSQL anonymous block in migration 13 with Elixir code using `Ecto.UUID.generate/0` and `repo().insert_all/3`; (2) replace `:jsonb` with `:map` and `{:array, :map}` in migration 17; (3) rewrite the `purchased = false` partial index in migration 04 as a raw `execute` SQL statement using `WHERE purchased = 0`.

Critical finding on scope: the `:where` option in `create unique_index` is SUPPORTED by ecto_sqlite3 for all other partial indexes (those using `IS NOT NULL` conditions). Only the `purchased = false` boolean condition needs special handling because SQLite stores booleans as integers and the Ecto DSL passes the string as-is to SQLite — `purchased = false` is not valid SQLite syntax whereas `purchased = 0` is. The REQUIREMENTS.md specification to use `execute` SQL for this specific index is correct.

**Primary recommendation:** Apply three surgical file edits (migrations 04, 13, 17), verify the `UPDATE ... FROM` syntax in migration 20260210024026 works on SQLite 3.33+, then run `mix ecto.reset` to confirm all ~60 migrations execute cleanly.

---

## Standard Stack

### Core (already installed — Phase 1 complete)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto_sqlite3` | `~> 0.22` | SQLite Ecto adapter | Already installed; serializes `:map` and `{:array, :map}` as JSON text via Jason |
| `exqlite` | transitive (`~> 0.22`) | SQLite NIF driver | Bundles SQLite 3.47+ — well above 3.33.0 required for `UPDATE ... FROM` |
| `ecto_sql` | `~> 3.13` | Migration runner | Already installed; `repo()` helper available in all migrations |

### No new dependencies needed for Phase 2.

All tooling (`Ecto.UUID`, `repo()`, `execute/1`, `:map`, `{:array, :map}`) is already available via the existing stack.

---

## Architecture Patterns

### Files to Edit (complete list for Phase 2)

```
server/priv/repo/migrations/
├── 20260101000004_create_inventory.exs        # MIGR-03: partial index boolean condition
├── 20260101000013_add_household_id_to_data_tables.exs  # MIGR-01: PL/pgSQL block
└── 20260101000017_create_user_preferences.exs  # MIGR-02: :jsonb type
```

All other migrations are compatible with SQLite as-is (confirmed by full grep scan).

### Pattern 1: Replacing PL/pgSQL Block with Elixir (MIGR-01)

**What:** Migration 13 opens with a PL/pgSQL `DO $$ ... END $$;` block that loops over users, calls `gen_random_uuid()`, inserts into `households`, and updates `users`. SQLite has no PL/pgSQL engine.

**Replacement strategy:** Use `execute/1` with an anonymous function that calls `repo()`. Inside, use `Ecto.UUID.generate/0` to produce UUIDs in Elixir, then issue individual SQL statements via `repo().query!/2`.

**Key API facts (verified against hexdocs.pm/ecto_sql/Ecto.Migration.html):**
- `repo()` is available inside any migration as a helper function returning the migrator repo
- `execute(fn -> ... end)` runs Elixir code as part of the migration (not deferred DDL)
- `repo().query!(sql, params, opts)` executes raw SQL immediately
- `Ecto.UUID.generate/0` returns a UUID string like `"3d2f8741-093b-49d5-9860-beb07902ceaf"`

**Pattern:**
```elixir
# Source: hexdocs.pm/ecto_sql/Ecto.Migration.html#module-executing-and-flushing
execute fn ->
  # Fetch users that need a household
  {:ok, %{rows: users}} =
    repo().query("SELECT id, name, email FROM users WHERE household_id IS NULL", [])

  now = DateTime.utc_now() |> DateTime.truncate(:second)
  now_str = DateTime.to_iso8601(now)

  Enum.each(users, fn [user_id, name, email] ->
    household_id = Ecto.UUID.generate()
    household_name = (name || email) <> "'s Household"

    repo().query!(
      "INSERT INTO households (id, name, inserted_at, updated_at) VALUES (?, ?, ?, ?)",
      [household_id, household_name, now_str, now_str]
    )

    repo().query!(
      "UPDATE users SET household_id = ? WHERE id = ?",
      [household_id, user_id]
    )
  end)
end
```

**Critical detail:** The migration runs at `mix ecto.migrate` time, after all `create table` DDL has completed for prior migrations. The `households` table exists before migration 13 runs (created in migration 12). The `users` table has `household_id` added by the `alter table` block AFTER this execute call — confirm the column is added before the UPDATE queries run. In the current migration, the `DO $$` block runs first (before the `alter table` calls), meaning the UPDATE of `users.household_id` would fail because the column doesn't exist yet. The CORRECT rewrite must move the Elixir block to execute AFTER the `alter table` calls that add `household_id` to `users`.

**Revised migration structure:**
```elixir
def up do
  # Step 1: Add household_id columns to all tables
  alter table(:tasks) do
    add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
  end
  # ... (all other alter table calls) ...

  # Step 2: Create households for users and back-fill all household_id columns
  execute fn ->
    # ... Elixir loop using repo() and Ecto.UUID.generate/0 ...
  end

  # Step 3: Create indexes
  create index(:tasks, [:household_id])
  # ...
end
```

Wait — reading migration 13 more carefully: the PL/pgSQL block creates households AND sets `users.household_id`. The `users` table already has `household_id` from migration 12 (the `create_households` migration). The `alter table` calls in migration 13 add `household_id` to the OTHER tables (tasks, task_templates, tags, etc.). So the PL/pgSQL block's `UPDATE users SET household_id = ...` works because the `users.household_id` column already exists (from migration 12). The Elixir replacement block can keep the same position (first in the function).

### Pattern 2: Replacing :jsonb Type (MIGR-02)

**What:** Migration 17 uses `:jsonb` for `dashboard_widgets` and `settings`. SQLite has no JSONB type.

**ecto_sqlite3 behavior (verified against hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html):**
- `:map` — stored as JSON text (`:string` mode by default). Use for single JSON objects.
- `{:array, :map}` — stored as JSON array text. Use for arrays of objects.
- The adapter uses Jason to encode/decode these automatically.
- The `default:` value must be a string in migrations for JSON columns.

**Replacement:**
```elixir
# Source: hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html
# BEFORE:
add :dashboard_widgets, :jsonb, default: "[]"
add :settings, :jsonb, default: "{}"

# AFTER:
add :dashboard_widgets, {:array, :map}, default: []
add :settings, :map, default: %{}
```

**Note on defaults:** In ecto_sqlite3, the `default:` for a `:map` column should be an Elixir value (`%{}` or `[]`), not a JSON string. The adapter serializes defaults to the database.

### Pattern 3: Replacing Partial Index with Boolean Condition (MIGR-03)

**What:** Migration 04 uses `where: "purchased = false"` in a `create unique_index`. `false` is not recognized by SQLite as a boolean literal in all contexts — SQLite stores booleans as integers (0/1). The requirement specifies replacing with a raw `execute` SQL statement using `WHERE purchased = 0`.

**Important nuance:** SQLite 3.23.0+ (released 2018) recognizes `TRUE` and `FALSE` as aliases for `1` and `0`. However, `purchased = false` (the Elixir atom passed as a string) may not be recognized depending on context. The requirement to use `purchased = 0` is the safest approach.

**Additional nuance:** The `where:` option in `create unique_index` IS supported by ecto_sqlite3 for conditions like `IS NOT NULL`. The REQUIREMENTS.md specifically calls for replacing this particular index with `execute` SQL — use that approach as specified.

**Replacement:**
```elixir
# Source: sqlite.org/partialindex.html (verified)
# REMOVE:
create unique_index(:shopping_list_items, [:user_id, :inventory_item_id], where: "purchased = false")

# REPLACE WITH:
execute """
CREATE UNIQUE INDEX shopping_list_items_user_id_inventory_item_id_index
ON shopping_list_items (user_id, inventory_item_id)
WHERE purchased = 0
"""
```

**Index naming:** Ecto auto-generates the index name as `{table}_{columns}_index`. When using raw SQL `execute`, you must provide the name explicitly. Use the same auto-generated name Ecto would have used to maintain consistency with the `down` function and any constraint references.

**Down function:** The `create_inventory.exs` migration uses `def change` (not `def up`/`def down`). Switching from `def change` to `def up`/`def down` is necessary when using `execute` with raw SQL that cannot be automatically reversed. The `down` function should `execute "DROP INDEX IF EXISTS shopping_list_items_user_id_inventory_item_id_index"`.

### Anti-Patterns to Avoid

- **Leaving `:jsonb` in migration 17:** ecto_sqlite3 will silently create a TEXT column without error on some versions, but the type annotation is semantically wrong and may cause issues with schema reflection. Replace it.
- **Using `purchased = false` in the WHERE clause:** Pass the literal integer `0` instead. `false` is not universally recognized as a boolean literal in SQLite partial index conditions.
- **Placing the Elixir `execute fn ->` block at the wrong position in migration 13:** The `repo().query!` calls run immediately when the anonymous function executes. DDL before it (like `alter table`) must have already been flushed. Use `flush/0` explicitly if needed before the `execute fn ->` block if alter table calls precede it.
- **Using `repo().insert_all/3` instead of `repo().query!/2`:** `insert_all` with schema-less maps works for simple cases but does not handle the dynamic `NOW()` timestamp generation as cleanly as raw SQL. Use `repo().query!/2` with parameterized SQL.
- **Forgetting to handle the `down` migration for MIGR-03:** Since `def change` cannot automatically reverse a raw `execute` SQL statement, the migration must be converted to `def up`/`def down`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UUID generation | Custom `:rand`-based UUID | `Ecto.UUID.generate/0` | Correct RFC 4122 UUID v4; already imported via Ecto |
| Timestamp strings | Manual `DateTime` formatting | `DateTime.utc_now() \|> DateTime.truncate(:second) \|> DateTime.to_iso8601/1` | Produces the ISO 8601 format SQLite stores for `:utc_datetime` columns |
| JSON serialization for migration defaults | Manual `Jason.encode!` in DDL | Elixir values in `default:` (`%{}`, `[]`) | ecto_sqlite3 handles serialization automatically |
| Partial indexes for NULL conditions | Custom `execute` SQL for every partial index | Keep the `where:` option on `create unique_index` for `IS NOT NULL` conditions | ecto_sqlite3 passes `where:` through to SQLite's `CREATE INDEX ... WHERE` which is natively supported |

**Key insight:** Only one partial index needs the `execute` SQL treatment (the boolean `purchased = false` one). All `IS NOT NULL` partial indexes in other migrations (`20260201000002_add_uniqueness_constraints.exs`, `20260101000018_create_shopping_lists.exs`, `20260201201001_enhance_store_address_fields.exs`) can keep the Ecto DSL `where:` option because SQLite supports `IS NOT NULL` as a valid partial index condition.

---

## Common Pitfalls

### Pitfall 1: UPDATE ... FROM Syntax in the Last Migration

**What goes wrong:** Migration `20260210024026_backfill_budget_entry_purchase_ids.exs` uses:
```sql
UPDATE budget_entries
SET purchase_id = p.id
FROM purchases p
WHERE p.budget_entry_id = budget_entries.id
  AND budget_entries.purchase_id IS NULL
```
The `FROM` clause in `UPDATE` was not supported in SQLite before version 3.33.0 (2020-08-14).

**Why it might not go wrong:** exqlite bundles SQLite 3.47.x (as of late 2024 releases). This is well above 3.33.0. On development and production machines using the bundled SQLite, this migration will run correctly.

**How to avoid risk:** Confirm by running `mix ecto.migrate` locally. If the migration fails with a syntax error, replace with a subquery form:
```sql
UPDATE budget_entries
SET purchase_id = (
  SELECT p.id FROM purchases p
  WHERE p.budget_entry_id = budget_entries.id
)
WHERE EXISTS (
  SELECT 1 FROM purchases p
  WHERE p.budget_entry_id = budget_entries.id
)
AND purchase_id IS NULL
```

**Confidence:** HIGH that it works (SQLite 3.47 is bundled; `UPDATE FROM` has been supported since 3.33 which is 4+ years old). LOW risk of failure.

### Pitfall 2: flush/0 Required Between DDL and Elixir Repo Calls

**What goes wrong:** In Ecto migrations, DDL commands (`alter table`, `create index`) are queued and executed at the end of the callback — they are NOT executed immediately. If a `repo().query!` call inside an `execute fn ->` block runs before a preceding `alter table` call has been flushed, the schema change may not yet be in effect.

**Why it happens:** Ecto batches DDL for performance. The `execute/1` with an anonymous function executes immediately, but preceding DDL may be queued.

**How to avoid:** Call `flush/0` before any `execute fn ->` block that depends on DDL applied in the same migration:
```elixir
def up do
  alter table(:users) do
    add :household_id, references(:households, type: :binary_id)
  end

  flush()  # Force DDL to execute before the Elixir block

  execute fn ->
    repo().query!("UPDATE users SET household_id = ?", [...])
  end
end
```

**For migration 13:** The PL/pgSQL block was FIRST (before `alter table` calls). The Elixir replacement should also be first, OR have a `flush()` before it if DDL precedes it. Since `users.household_id` already exists (from migration 12), the Elixir block can stay first without needing `flush/0`.

**Warning signs:** `(Exqlite.Error) no such column: household_id` during migration run.

### Pitfall 3: :jsonb Default Values

**What goes wrong:** Using `default: "[]"` (string) for `{:array, :map}` or `default: "{}"` (string) for `:map` in ecto_sqlite3 migrations may store the literal string `"[]"` in the column default rather than an empty JSON array.

**Why it happens:** In PostgreSQL, `default: "[]"` was passed as a SQL literal string. In ecto_sqlite3, the default should be the Elixir value.

**How to avoid:** Use `default: []` for `{:array, :map}` and `default: %{}` for `:map`.

### Pitfall 4: Index Name Mismatch for execute-Based Partial Index

**What goes wrong:** When replacing `create unique_index(:shopping_list_items, [:user_id, :inventory_item_id], where: "purchased = false")` with a raw `execute "CREATE UNIQUE INDEX ..."`, using a different index name than Ecto would auto-generate causes the `down` migration to fail (the index name doesn't match what Ecto expects to drop).

**How to avoid:** Use the exact same name Ecto auto-generates: `shopping_list_items_user_id_inventory_item_id_index`. Verify the name by checking the Ecto naming convention: `{table}_{columns}_index`.

### Pitfall 5: Migration 13 — Column Already Exists vs. NOT NULL on First Seed

**What goes wrong:** Migration 13 back-fills `household_id` for all existing users. On a FRESH database (first run), there are no users yet. The `execute fn ->` block will iterate over an empty result set — this is correct behavior and should be a no-op. Do not add guards that fail on empty results.

**How to avoid:** The `Enum.each/2` over an empty list is a safe no-op. No special handling required for fresh databases.

---

## Code Examples

Verified patterns from official sources:

### Full Rewrite of Migration 13 (MIGR-01)

```elixir
# Source: hexdocs.pm/ecto_sql/Ecto.Migration.html (repo() and execute fn)
# Source: hexdocs.pm/ecto/Ecto.UUID.html (Ecto.UUID.generate/0)

defmodule MegaPlanner.Repo.Migrations.AddHouseholdIdToDataTables do
  use Ecto.Migration

  def up do
    # Step 1: Create households for each user without one, and set users.household_id
    # (users.household_id column already added in migration 12)
    execute fn ->
      {:ok, %{rows: users}} =
        repo().query("SELECT id, name, email FROM users WHERE household_id IS NULL", [])

      now =
        DateTime.utc_now()
        |> DateTime.truncate(:second)
        |> DateTime.to_iso8601()

      Enum.each(users, fn [user_id, name, email] ->
        household_id = Ecto.UUID.generate()
        household_name = (name || email) <> "'s Household"

        repo().query!(
          "INSERT INTO households (id, name, inserted_at, updated_at) VALUES (?, ?, ?, ?)",
          [household_id, household_name, now, now]
        )

        repo().query!(
          "UPDATE users SET household_id = ? WHERE id = ?",
          [household_id, user_id]
        )
      end)
    end

    # Step 2: Add household_id to all other tables
    alter table(:tasks) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    # ... (remaining alter table calls unchanged) ...

    # Step 3: Back-fill household_id in all other tables
    execute "UPDATE tasks SET household_id = (SELECT household_id FROM users WHERE users.id = tasks.user_id)"
    # ... (remaining UPDATE calls unchanged) ...

    # Step 4: Create indexes (unchanged)
    create index(:tasks, [:household_id])
    # ...
  end

  def down do
    # ... (unchanged from original) ...
  end
end
```

### Rewrite of Migration 17 :jsonb Columns (MIGR-02)

```elixir
# Source: hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html

# BEFORE:
add :dashboard_widgets, :jsonb, default: "[]"
add :settings, :jsonb, default: "{}"

# AFTER:
add :dashboard_widgets, {:array, :map}, default: []
add :settings, :map, default: %{}
```

### Rewrite of Partial Unique Index (MIGR-03)

```elixir
# Source: sqlite.org/partialindex.html
# Source: hexdocs.pm/ecto_sql/Ecto.Migration.html (execute/1)

# Migration must change from def change to def up/def down

def up do
  # ... (all create table calls unchanged) ...

  create index(:shopping_list_items, [:user_id])
  create index(:shopping_list_items, [:inventory_item_id])

  # Replace the DSL partial index with raw SQL using integer 0 for false
  execute """
  CREATE UNIQUE INDEX shopping_list_items_user_id_inventory_item_id_index
  ON shopping_list_items (user_id, inventory_item_id)
  WHERE purchased = 0
  """
end

def down do
  execute "DROP INDEX IF EXISTS shopping_list_items_user_id_inventory_item_id_index"
  drop index(:shopping_list_items, [:inventory_item_id])
  drop index(:shopping_list_items, [:user_id])
  drop table(:shopping_list_items)
  drop table(:inventory_items)
  drop table(:inventory_sheets)
end
```

### Verifying Migration 13 Reads user_id Correctly

The `users` table uses `binary_id` (stored as binary in SQLite). Rows fetched via `repo().query!` return raw binary values for UUID columns. When passing a fetched `user_id` back to `UPDATE users SET household_id = ? WHERE id = ?`, the binary value is passed through correctly as a positional parameter without conversion.

### Checking for Remaining PostgreSQL Constructs After Edits

```bash
# Run from server/ directory — must return zero results after Phase 2
grep -rn ":jsonb\|gen_random_uuid" priv/repo/migrations/

# Verify the partial index with boolean was replaced
grep -rn "purchased = false" priv/repo/migrations/
```

---

## Scope Audit: All PostgreSQL-Specific Constructs Found

Full grep scan of all 60+ migration files reveals exactly three PostgreSQL-specific issues (confirming REQUIREMENTS.md scope):

| File | Issue | Fix |
|------|-------|-----|
| `20260101000004_create_inventory.exs` | `where: "purchased = false"` in `create unique_index` | Replace with `execute` SQL using `WHERE purchased = 0` |
| `20260101000013_add_household_id_to_data_tables.exs` | `DO $$ ... gen_random_uuid() ... END $$;` PL/pgSQL block | Replace with `execute fn ->` using `Ecto.UUID.generate/0` |
| `20260101000017_create_user_preferences.exs` | `:jsonb` type for two columns | Replace with `{:array, :map}` and `:map` |

**Other `:where` option usages (NOT requiring changes):**
- `20260201000002_add_uniqueness_constraints.exs` — five `IS NOT NULL` partial indexes
- `20260101000018_create_shopping_lists.exs` — `where: "is_auto_generated = true"` (integer 1; TRUE keyword; should be verified)
- `20260201201001_enhance_store_address_fields.exs` — `where: "store_id IS NOT NULL"`
- `20260208000000_remove_purchase_brand_item_unique.exs` — in `down` function only

**Note on `is_auto_generated = true`:** Migration 18 has `where: "is_auto_generated = true"`. SQLite recognizes `TRUE` as an alias for `1` since version 3.23.0 (bundled SQLite is 3.47+). This should work but is worth monitoring during `mix ecto.reset` verification. If it fails, apply the same fix: replace with `is_auto_generated = 1`.

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `DO $$ ... gen_random_uuid() ... END $$;` | `execute fn -> ... Ecto.UUID.generate/0 ... end` | Pure Elixir; no PL/pgSQL engine required |
| `:jsonb` migration type | `:map` (single object) or `{:array, :map}` (array) | Stored as JSON text via ecto_sqlite3; Jason serializes/deserializes |
| `where: "purchased = false"` DSL | `execute "CREATE UNIQUE INDEX ... WHERE purchased = 0"` | Raw SQL with integer boolean; explicit and unambiguous |
| `gen_random_uuid()` (PostgreSQL function) | `Ecto.UUID.generate/0` (application-layer) | No DB extension required; works identically across databases |

---

## Open Questions

1. **`is_auto_generated = true` in migration 18**
   - What we know: SQLite 3.23+ recognizes `TRUE` as `1`; exqlite bundles SQLite 3.47+
   - What's unclear: Whether the Ecto DSL string `"is_auto_generated = true"` passes through as-is or gets transformed
   - Recommendation: Run `mix ecto.reset` and observe. If migration 18 fails, apply same fix as MIGR-03 (replace with `execute` SQL using `is_auto_generated = 1`). Do NOT preemptively fix — only fix what breaks.

2. **Row format of `repo().query!` for binary_id columns**
   - What we know: `repo().query!` returns raw rows; UUID fields stored as binary in SQLite
   - What's unclear: Whether the binary values need encoding when passed back to `UPDATE ... WHERE id = ?`
   - Recommendation: SQLite treats binary blobs as values and positional parameter binding preserves the bytes. No encoding/decoding needed in the migration. Validate during MIGR-04.

3. **`flush/0` necessity in migration 13 rewrite**
   - What we know: `execute fn ->` runs immediately; the `DO $$` block was first in the original migration; `users.household_id` exists from migration 12
   - What's unclear: Whether any DDL in migration 13 that precedes the Elixir block (if restructured) needs explicit `flush/0`
   - Recommendation: Keep the `execute fn ->` block as the FIRST action in `up/0`, matching the original structure. No `flush/0` needed.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) + `mix ecto.migrate` |
| Config file | `server/test/test_helper.exs` (exists) |
| Quick run command | `cd server && mix ecto.migrate --log-migrator-sql` |
| Full suite command | `cd server && mix ecto.reset` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MIGR-01 | PL/pgSQL block replaced; `mix ecto.migrate` passes migration 13 | smoke | `cd server && mix ecto.migrate 2>&1 \| grep -E "error\|Error\|migrated"` | ✅ (migration file) |
| MIGR-02 | `:jsonb` replaced; `mix ecto.migrate` passes migration 17 | smoke | `cd server && mix ecto.migrate 2>&1 \| grep -E "error\|Error\|migrated"` | ✅ (migration file) |
| MIGR-03 | Partial index with `purchased = 0`; `mix ecto.reset` passes migration 04 | smoke | `cd server && grep -rn "purchased = false" priv/repo/migrations/` | ✅ (grep returns 0 results) |
| MIGR-04 | All migrations pass from scratch | integration | `cd server && mix ecto.reset` | ✅ (all migration files) |

### Verification Commands (from REQUIREMENTS.md success criteria)

```bash
# Success criterion 2: must return zero results
grep -rn ":jsonb\|gen_random_uuid" server/priv/repo/migrations/

# Success criterion 3: partial index uses WHERE purchased = 0
grep -rn "purchased" server/priv/repo/migrations/

# Success criterion 1: full clean migration run
cd server && mix ecto.reset
```

### Sampling Rate

- **Per task commit:** `cd server && mix compile --warnings-as-errors`
- **Per wave merge:** `cd server && mix ecto.migrate` (incremental)
- **Phase gate:** `cd server && mix ecto.reset` — all ~60 migrations complete without errors

### Wave 0 Gaps

None — existing migration files and test infrastructure cover all phase requirements. Phase 2 verification is migration-runner and grep based, not ExUnit test based.

---

## Sources

### Primary (HIGH confidence)

- `server/priv/repo/migrations/20260101000004_create_inventory.exs` — Read directly; confirmed `where: "purchased = false"` at line 43
- `server/priv/repo/migrations/20260101000013_add_household_id_to_data_tables.exs` — Read directly; confirmed PL/pgSQL block at lines 5-19
- `server/priv/repo/migrations/20260101000017_create_user_preferences.exs` — Read directly; confirmed `:jsonb` at lines 13 and 19
- `server/priv/repo/migrations/20260201000002_add_uniqueness_constraints.exs` — Read directly; confirmed `IS NOT NULL` partial indexes (ecto_sqlite3 compatible)
- `server/priv/repo/migrations/20260210024026_backfill_budget_entry_purchase_ids.exs` — Read directly; confirmed `UPDATE ... FROM` syntax
- [hexdocs.pm/ecto_sql/Ecto.Migration.html](https://hexdocs.pm/ecto_sql/Ecto.Migration.html) — `repo()` helper, `execute/1` with anonymous function, `flush/0`
- [hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html](https://hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html) — `:map_type`, `{:array, :map}`, JSON serialization behavior
- [sqlite.org/partialindex.html](https://www.sqlite.org/partialindex.html) — SQLite partial index WHERE clause support; boolean column example
- [sqlite.org/datatype3.html](https://sqlite.org/datatype3.html) — Boolean storage as integers 0/1; TRUE/FALSE as aliases since SQLite 3.23.0
- [sqlite.org/lang_update.html](https://sqlite.org/lang_update.html) — `UPDATE ... FROM` syntax; confirmed supported since SQLite 3.33.0 (2020-08-14)

### Secondary (MEDIUM confidence)

- WebSearch results on `ecto_sqlite3` `:where` option support — confirmed via SQLite official docs that partial indexes with WHERE work natively
- WebSearch results on exqlite bundled SQLite versions — changelog shows 3.47.x bundled as of late 2024; well above 3.33.0 threshold
- Grep of all 60+ migration files — confirmed exactly three PostgreSQL-specific issues; no others found

### Tertiary (LOW confidence)

- Default value format for `{:array, :map}` (`default: []` vs `default: "[]"`) — verified from webSearch but not from hexdocs directly. MEDIUM confidence.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified in place from Phase 1; no new deps needed
- Architecture (migration rewrites): HIGH — all three target migrations read directly; exact patterns documented
- Pitfalls: HIGH — flush/0, binary_id passthrough, and boolean integer issues are documented from official sources
- Scope audit: HIGH — full grep of all 60+ migration files confirmed exactly three issues

**Research date:** 2026-03-07
**Valid until:** 2026-06-07 (ecto_sqlite3 0.22.x API is stable; SQLite 3.33+ UPDATE FROM is stable)
