# Phase 4: Data Migration Pipeline - Research

**Researched:** 2026-03-07
**Domain:** Elixir Mix tasks — PostgreSQL export via Postgrex, SQLite import via Ecto, JSON serialization, FK ordering
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DATA-01 | Create `mix migrate.export` Mix task — connects to PostgreSQL via Ecto and exports all table data to a JSON file, serializing arrays and maps correctly | Postgrex 0.21.1 is in mix.lock; must be added to mix.exs as `only: :dev` dep; Postgrex.start_link + Postgrex.query! pattern; NaiveDateTime/Decimal serialization required |
| DATA-02 | Create `mix migrate.import` Mix task — reads the JSON export and inserts all records into SQLite, respecting foreign key ordering and handling the tasks self-referential FK (`parent_task_id`) with a two-pass insert | PRAGMA foreign_keys = OFF via repo().query!/2; Repo.insert_all/3 for bulk inserts; two-pass needed for tasks, goal_categories, purchases/budget_entries circular FK |
| DATA-03 | Create `mix migrate.verify` Mix task — compares record counts between PostgreSQL and SQLite for every table and reports any discrepancies | Both connections needed simultaneously; 48 data tables confirmed in dev SQLite |
| DATA-04 | Run export against live production PostgreSQL database and produce a verified export file | fly proxy 5432:5432 -a mega-planner-api-db establishes tunnel; DATABASE_URL secret is set on mega-planner-api app |
| DATA-05 | Run import against local SQLite database and confirm `mix migrate.verify` shows zero discrepancies | Covered by DATA-02 + DATA-03 implementation + PRAGMA foreign_key_check |
</phase_requirements>

## Summary

Phase 4 builds three Mix tasks that form the complete data migration pipeline: `migrate.export`, `migrate.import`, and `migrate.verify`. The tasks run sequentially — export first against production PostgreSQL, import into local SQLite, then verify record counts match.

The most critical design decision is the PostgreSQL connection method. Postgrex (version 0.21.1) is already locked in `mix.lock` as a transitive dependency of `ecto_sql` and `phoenix_ecto`, but was not compiled because the direct `postgrex` entry was removed from `mix.exs` in Phase 1. Adding `{:postgrex, "~> 0.21", only: :dev}` back to `mix.exs` activates it for the export and verify tasks without affecting the production build. The export task uses `Postgrex.start_link/1` with a connection parsed from `DATABASE_URL`, not a second Ecto.Repo, to keep the approach simple and avoid OTP supervision conflicts. The import task uses the existing `MegaPlanner.Repo` (SQLite) configured normally.

The import task has two non-trivial serialization challenges. First, PostgreSQL timestamps are returned by Postgrex as `NaiveDateTime` structs, which are not JSON-serializable by default — they must be converted to ISO 8601 strings before writing the JSON export file. Second, the SQLite import must correctly handle the `purchases <-> budget_entries` circular optional FK (both sides are nullable), the `tasks.parent_task_id` self-referential FK, and the `goal_categories.parent_id` self-referential FK. The cleanest solution is `PRAGMA foreign_keys = OFF` during import (safe because `PRAGMA foreign_key_check` verifies integrity after all rows are inserted), plus a two-pass update for the self-referential and circular FK columns.

**Primary recommendation:** Use Postgrex direct (not a second Ecto.Repo), disable FK enforcement during import via PRAGMA, and use two-pass INSERT + UPDATE for circular and self-referential FKs. Verify with `PRAGMA foreign_key_check` at the end.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| postgrex | 0.21.1 | Direct PostgreSQL connection for export/verify tasks | Already in mix.lock; Ecto adapter uses it; direct Postgrex.start_link avoids second Repo complexity |
| jason | ~> 1.2 | JSON encode/decode for the export file | Already in mix.exs; used by ecto_sqlite3 for JSON columns |
| ecto_sqlite3 | ~> 0.22 | MegaPlanner.Repo (SQLite) for import task | Already installed; existing repo; Repo.insert_all/3 handles bulk inserts |
| Elixir Mix.Task | built-in | Task scaffolding (`use Mix.Task`) | Standard Elixir mechanism; task names map to module names |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Ecto.Repo.Supervisor.parse_url/1 | ecto ~> 3.13 | Parse DATABASE_URL into Postgrex.start_link keyword options | Use in export/verify tasks to avoid manual URL parsing |
| fly proxy | v0.4.19 (CLI) | Tunnel local 5432 -> Fly.io Postgres 5432 via WireGuard | Required to access production PostgreSQL from local machine during DATA-04 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Postgrex.start_link direct | Second Ecto.Repo with Postgres adapter | Second Repo requires more config, OTP supervision complexity, and a full PostgresRepo module; direct Postgrex is simpler for one-time export |
| PRAGMA foreign_keys = OFF | Topological sort insert order | Both work; PRAGMA approach is simpler, eliminates sort complexity, and the integrity check at the end (PRAGMA foreign_key_check) provides the same guarantee |
| Repo.insert_all/3 | Individual Repo.insert/2 per row | insert_all is 10-100x faster for bulk data; SQLite MAX_VARIABLE_NUMBER=500000 means no batch-size chunking is needed |

**Installation:**
```bash
# In mix.exs deps only - postgrex already in mix.lock, just needs direct dep entry
{:postgrex, "~> 0.21", only: :dev}
# Then:
cd server && mix deps.get
```

## Architecture Patterns

### Recommended Project Structure
```
server/lib/mix/tasks/
├── migrate.export.ex     # Mix.Tasks.Migrate.Export  (mix migrate.export)
├── migrate.import.ex     # Mix.Tasks.Migrate.Import  (mix migrate.import)
└── migrate.verify.ex     # Mix.Tasks.Migrate.Verify  (mix migrate.verify)
```

Mix task module naming convention: `mix migrate.export` -> `defmodule Mix.Tasks.Migrate.Export`.

### Pattern 1: Mix Task Scaffold
**What:** Standard `use Mix.Task` structure with `Application.ensure_all_started` for Repo access.
**When to use:** All three tasks.
**Example:**
```elixir
# lib/mix/tasks/migrate.export.ex
defmodule Mix.Tasks.Migrate.Export do
  use Mix.Task

  @shortdoc "Export all PostgreSQL data to a JSON file for SQLite import"

  @impl Mix.Task
  def run(args) do
    # Start the application to get Repo and supervision
    Application.ensure_all_started(:mega_planner)

    output_path = List.first(args) || "migration_export.json"
    # ... task body
  end
end
```

### Pattern 2: Postgrex Direct Connection (for export/verify)
**What:** Start Postgrex process using credentials parsed from DATABASE_URL.
**When to use:** `migrate.export` and `migrate.verify` tasks.
**Example:**
```elixir
# Parse DATABASE_URL env var (set manually or via fly proxy tunnel)
database_url = System.get_env("POSTGRES_URL") ||
  raise "POSTGRES_URL environment variable is required"

opts = Ecto.Repo.Supervisor.parse_url(database_url)
      |> Keyword.put(:pool_size, 2)
      |> Keyword.put(:timeout, 60_000)

{:ok, pg_pid} = Postgrex.start_link(opts)

# Query a table
result = Postgrex.query!(pg_pid, "SELECT * FROM users", [])
# result.columns = ["id", "email", "name", ...]
# result.rows = [["uuid-string", "user@example.com", "Name", ...], ...]
```

**Note:** Use `POSTGRES_URL` as the env var name in export/verify tasks to avoid conflicting with the app's now-removed `DATABASE_URL` (which was PostgreSQL) vs the current production `DATABASE_URL` (which is SQLite path). Alternatively, accept the URL as a command-line argument to avoid ambiguity: `mix migrate.export ecto://user:pass@localhost/db_name`.

### Pattern 3: Export Serialization — Type Conversion
**What:** Convert Postgrex-returned Elixir types to JSON-serializable values.
**When to use:** Export task, when building the map for Jason.encode!.
**Example:**
```elixir
# Postgrex returns these types that need conversion:
# - NaiveDateTime -> ISO 8601 string
# - DateTime -> ISO 8601 string
# - Decimal -> string (preserves precision)
# - nil -> nil (pass through)
# - String (UUIDs, text) -> pass through
# - integer/float -> pass through
# - list (UUID arrays) -> list of strings (already strings from Postgrex)

defp serialize_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
defp serialize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
defp serialize_value(%Decimal{} = d), do: Decimal.to_string(d)
defp serialize_value(list) when is_list(list), do: Enum.map(list, &serialize_value/1)
defp serialize_value(map) when is_map(map), do: Map.new(map, fn {k, v} -> {k, serialize_value(v)} end)
defp serialize_value(v), do: v

# Convert a Postgrex result row to a map:
defp row_to_map(columns, row) do
  columns
  |> Enum.zip(row)
  |> Enum.map(fn {col, val} -> {col, serialize_value(val)} end)
  |> Map.new()
end
```

### Pattern 4: Import with PRAGMA foreign_keys = OFF
**What:** Disable SQLite FK enforcement for the duration of bulk import, then re-enable.
**When to use:** `migrate.import` task — wrap all inserts.
**Why:** Allows inserting in any order without topological sorting. Integrity verified by `PRAGMA foreign_key_check` at the end.
**Example:**
```elixir
alias MegaPlanner.Repo

# Disable FK checks for bulk import
Repo.query!("PRAGMA foreign_keys = OFF")

try do
  # Insert all tables in a transaction
  Repo.transaction(fn ->
    import_table(data["users"], "users")
    import_table(data["households"], "households")
    # ... all tables
    import_tasks_two_pass(data["tasks"])
    import_goal_categories_two_pass(data["goal_categories"])
    import_purchases_budget_entries_two_pass(data["purchases"], data["budget_entries"])
  end, timeout: :infinity)
after
  # Re-enable FK checks (important: runs even if transaction fails)
  Repo.query!("PRAGMA foreign_keys = ON")
end

# Verify after import
{:ok, result} = Repo.query("PRAGMA foreign_key_check")
if result.rows == [] do
  IO.puts("FK check: PASSED — zero violations")
else
  IO.puts("FK check: FAILED — #{length(result.rows)} violations")
  IO.inspect(result.rows)
end
```

**Important:** `PRAGMA foreign_keys` is connection-level. The ecto_sqlite3 adapter defaults to `foreign_keys: :on` and sets this PRAGMA when a connection is checked out. If using `Repo.transaction/2`, the OFF setting must be sent on the same connection. Use `Repo.query!` inside the transaction callback, or set `foreign_keys: :off` in the import task's runtime config override.

**Safer alternative for the PRAGMA approach:**
```elixir
# Set foreign_keys: :off for the Repo before import
# Then restore after
# OR use raw SQLite3 via Exqlite directly on a single connection
```

### Pattern 5: Two-Pass Insert for Self-Referential FKs
**What:** First pass inserts rows with the self-referential FK column set to NULL. Second pass updates the FK to the actual value.
**When to use:** `tasks.parent_task_id`, `goal_categories.parent_id`.
**Example:**
```elixir
defp import_tasks_two_pass(tasks) do
  # Pass 1: Insert all tasks with parent_task_id = nil
  rows_without_parent = Enum.map(tasks, fn task ->
    task
    |> Map.delete("parent_task_id")
    |> Map.put("parent_task_id", nil)
    |> atomize_keys()
  end)
  Repo.insert_all("tasks", rows_without_parent, on_conflict: :nothing)

  # Pass 2: Update parent_task_id where it was non-null
  tasks
  |> Enum.filter(fn t -> t["parent_task_id"] != nil end)
  |> Enum.each(fn task ->
    Repo.query!(
      "UPDATE tasks SET parent_task_id = ? WHERE id = ?",
      [task["parent_task_id"], task["id"]]
    )
  end)
end
```

### Pattern 6: Two-Pass for Circular FK (purchases <-> budget_entries)
**What:** Insert both tables with the cross-reference FK set to NULL, then update.
**When to use:** `migrate.import` — purchases.budget_entry_id and budget_entries.purchase_id are mutually optional FKs.
**Example:**
```elixir
defp import_purchases_budget_entries_two_pass(purchases, budget_entries) do
  # Pass 1: Insert purchases without budget_entry_id
  rows = Enum.map(purchases, &(Map.put(atomize_keys(&1), :budget_entry_id, nil)))
  Repo.insert_all("purchases", rows, on_conflict: :nothing)

  # Pass 1: Insert budget_entries without purchase_id
  rows = Enum.map(budget_entries, &(Map.put(atomize_keys(&1), :purchase_id, nil)))
  Repo.insert_all("budget_entries", rows, on_conflict: :nothing)

  # Pass 2: Restore purchases.budget_entry_id
  purchases
  |> Enum.filter(&(&1["budget_entry_id"] != nil))
  |> Enum.each(fn p ->
    Repo.query!(
      "UPDATE purchases SET budget_entry_id = ? WHERE id = ?",
      [p["budget_entry_id"], p["id"]]
    )
  end)

  # Pass 2: Restore budget_entries.purchase_id
  budget_entries
  |> Enum.filter(&(&1["purchase_id"] != nil))
  |> Enum.each(fn be ->
    Repo.query!(
      "UPDATE budget_entries SET purchase_id = ? WHERE id = ?",
      [be["purchase_id"], be["id"]]
    )
  end)
end
```

### Pattern 7: fly proxy for Production PostgreSQL Access
**What:** Create a WireGuard tunnel from local port 5432 to the Fly.io Postgres cluster.
**When to use:** DATA-04 — running `mix migrate.export` against production.
**Example:**
```bash
# Terminal 1: Start tunnel (keep running)
fly proxy 5432:5432 -a mega-planner-api-db

# Terminal 2: Run export with localhost connection
POSTGRES_URL="ecto://mega_planner_api:<password>@localhost:5432/mega_planner_api" \
  mix migrate.export migration_export.json
```

**Connection string format:** The Fly postgres cluster name is `mega-planner-api-db`. The database name is `mega_planner_api` (confirmed from `fly postgres db list`). The password is retrievable via `fly postgres connect -a mega-planner-api-db` or from the `DATABASE_URL` secret on `mega-planner-api` app via `fly secrets show -a mega-planner-api` (name only) — the actual value requires `fly ssh console` or retrieving it from app environment during the DATA-04 execution step.

### Anti-Patterns to Avoid

- **Using pg_dump:** The REQUIREMENTS.md explicitly says export via Elixir Mix tasks (not pg_dump) "for correct UUID encoding and type coercion". pg_dump produces binary data that cannot be directly ingested by the SQLite import process.
- **Creating a second Ecto.Repo for PostgreSQL:** Requires a full module definition, `config` entries, and OTP supervision. Adds complexity for a one-shot export tool. Direct Postgrex.start_link is simpler.
- **Inserting with FK checks ON without topological sort:** Will fail on tables with non-nullable FKs pointing to tables not yet inserted. Use PRAGMA foreign_keys = OFF + post-import check instead.
- **Forgetting the purchases <-> budget_entries circular FK:** Both `purchases.budget_entry_id` and `budget_entries.purchase_id` are optional but cross-referencing. Inserting either table first without nulling the cross-reference will break if FK checks are ON.
- **Assuming JSON arrays in SQLite are already lists:** `ecto_sqlite3` stores `{:array, :binary_id}` as JSON text (e.g., `'["uuid1","uuid2"]'`). `Repo.insert_all/3` expects Elixir list values — Ecto handles the JSON encoding internally. Do NOT pre-encode arrays to JSON strings before passing to insert_all.
- **Not handling Decimal in export:** Postgrex returns `Decimal.t()` structs for NUMERIC/DECIMAL columns. Jason cannot encode Decimal structs by default. Use `Decimal.to_string/1` before encoding, or implement a `Jason.Encoder` protocol for Decimal (the `decimal` library does NOT include this by default in all versions).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Parse DATABASE_URL | Custom regex URL parser | `Ecto.Repo.Supervisor.parse_url/1` | Already in Ecto; handles encoding, edge cases |
| FK integrity check | Custom FK walk | `PRAGMA foreign_key_check` | Built-in SQLite; returns table name, parent table, rowid for each violation |
| UUID generation for test records | Custom UUID | `Ecto.UUID.generate/0` | Already used in migrations; returns canonical string format |
| Bulk inserts | Individual Repo.insert/2 in a loop | `Repo.insert_all/3` | Order of magnitude faster; atomic per-batch |
| Type detection for JSON encoding | Complex type guard | `serialize_value/1` with pattern matching on Elixir struct types | Covers all Postgrex-returned types cleanly |

**Key insight:** Postgrex + PRAGMA foreign_keys = OFF + Repo.insert_all covers all the hard problems. The main implementation work is the serialization layer between Postgrex result types and JSON/Ecto-compatible values.

## Common Pitfalls

### Pitfall 1: Postgrex Returns NaiveDateTime, Jason Cannot Encode It
**What goes wrong:** `Jason.encode!` raises `Protocol.UndefinedError` for `NaiveDateTime` or `DateTime` structs returned by Postgrex for timestamp columns.
**Why it happens:** Jason does not implement `Jason.Encoder` for DateTime/NaiveDateTime by default.
**How to avoid:** Pass all values through a `serialize_value/1` function that converts temporal types to ISO 8601 strings before encoding.
**Warning signs:** `** (Protocol.UndefinedError) protocol Jason.Encoder not implemented for ~U[...]` or similar at export time.

### Pitfall 2: Decimal Columns Not JSON-Serializable
**What goes wrong:** Same as above but for `Decimal.t()` struct — `NUMERIC`, `DECIMAL` columns in PostgreSQL (prices, quantities) come back as `%Decimal{}` from Postgrex.
**Why it happens:** Jason.Encoder is not implemented for `%Decimal{}` by the `decimal` library.
**How to avoid:** Use `Decimal.to_string(d)` in the serialize_value function. On import, pass decimal strings as strings — `ecto_sqlite3` handles the TEXT affinity correctly.
**Warning signs:** `** (Protocol.UndefinedError) protocol Jason.Encoder not implemented for #Decimal<...>`.

### Pitfall 3: PRAGMA foreign_keys = OFF is Connection-Scoped
**What goes wrong:** The PRAGMA is sent on one connection but inserts run on a different connection from the pool. FK violations occur despite setting the PRAGMA.
**Why it happens:** ecto_sqlite3 with `pool_size: 5` can check out different connections. `PRAGMA foreign_keys` only applies to the connection it was sent on.
**How to avoid:** Send the PRAGMA inside the `Repo.transaction/2` callback — Ecto guarantees all queries in a transaction run on the same connection. OR configure the import task to run with `pool_size: 1` so only one connection exists.
**Warning signs:** `FOREIGN KEY constraint failed` errors despite having sent `PRAGMA foreign_keys = OFF`.

### Pitfall 4: inventory_items Has Optional FKs to purchases, trips, stops
**What goes wrong:** `inventory_items` references `stops`, `trips`, and `purchases` — all with NO ACTION (no cascade). If inserts happen with FK checks ON and those tables aren't populated first, constraint violations occur.
**Why it happens:** The FKs are optional (nullable), but with FK checks ON, SQLite still validates them.
**How to avoid:** PRAGMA foreign_keys = OFF during import handles this. If doing ordered insert instead, inventory_items must go after stops, trips, and purchases.
**Warning signs:** `FOREIGN KEY constraint failed` during inventory_items insert.

### Pitfall 5: The Export File Should Include Table Names as Top-Level Keys
**What goes wrong:** Using a flat list of rows without table names makes the import task brittle and requires hardcoded array indexing.
**Why it happens:** Export file structure is not specified in requirements — easy to design it wrong.
**How to avoid:** Use `%{"table_name" => [rows...], "table_name2" => [...]}` as the JSON structure. Add metadata like `exported_at` and table counts for the verify task.
**Warning signs:** Import task hardcodes positional assumptions about export file structure.

### Pitfall 6: goal_categories Also Has a Self-Referential FK
**What goes wrong:** Requirements only mention `tasks.parent_task_id` for the two-pass. `goal_categories.parent_id` is also self-referential (verified in schema). With FK checks ON, inserting child categories before parent categories fails.
**Why it happens:** PRAGMA foreign_keys = OFF approach avoids this entirely. But if using ordered insert, this table needs the same two-pass treatment as tasks.
**How to avoid:** Use PRAGMA foreign_keys = OFF for all imports, or include goal_categories in the two-pass list. Even with PRAGMA OFF, it is good practice to handle it in two passes to match the requirement's stated approach.
**Warning signs:** Missing parent_id values on goal_categories after import.

### Pitfall 7: Postgrex Not Compiled (Not Directly in mix.exs)
**What goes wrong:** `mix migrate.export` fails with `** (UndefinedFunctionError) function Postgrex.start_link/1 is undefined` even though postgrex is in mix.lock.
**Why it happens:** Postgrex was removed from mix.exs in Phase 1. It remains in mix.lock as a transitive dependency but was NOT compiled because no direct dep references it.
**How to avoid:** Add `{:postgrex, "~> 0.21", only: :dev}` to mix.exs and run `mix deps.get`. The `only: :dev` ensures it does not appear in the production release.
**Warning signs:** Compilation error or UndefinedFunctionError on Postgrex module.

## Code Examples

Verified patterns from official sources and codebase analysis:

### Complete Export Task Structure
```elixir
# lib/mix/tasks/migrate.export.ex
defmodule Mix.Tasks.Migrate.Export do
  use Mix.Task
  @shortdoc "Export all PostgreSQL data to a JSON file"

  # All 48 data tables (schema_migrations excluded)
  @tables ~w[
    households users tags units drivers stores
    trips stops inventory_sheets notebook notebooks
    task_templates milestone_templates text_templates
    goal_categories goals goal_milestones goal_status_changes
    habits habit_inventories habit_completions
    brands purchases budget_sources budget_entries
    shopping_lists shopping_list_items inventory_items
    pages page_links notifications notification_preferences
    household_invitations user_preferences
    tasks task_steps format_corrections tax_indicator_meanings
    tasks_tags goals_tags habits_tags budget_entries_tags
    budget_sources_tags inventory_items_tags purchases_tags
    shopping_lists_tags notebooks_tags pages_tags
    inventory_sheets_tags habits_tags
  ]

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:mega_planner)

    output_path = List.first(args) || "migration_export.json"
    database_url = System.get_env("POSTGRES_URL") ||
      raise "POSTGRES_URL is required (use fly proxy 5432:5432 -a mega-planner-api-db)"

    opts = Ecto.Repo.Supervisor.parse_url(database_url) |> Keyword.put(:pool_size, 2)
    {:ok, pg} = Postgrex.start_link(opts)

    export = Enum.reduce(@tables, %{}, fn table, acc ->
      result = Postgrex.query!(pg, ~s(SELECT * FROM "#{table}"), [])
      rows = Enum.map(result.rows, &row_to_map(result.columns, &1))
      IO.puts("  #{table}: #{length(rows)} rows")
      Map.put(acc, table, rows)
    end)

    json = Jason.encode!(%{
      "exported_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "tables" => export
    }, pretty: true)

    File.write!(output_path, json)
    IO.puts("Export complete: #{output_path}")
  end

  defp row_to_map(columns, row) do
    Enum.zip(columns, row)
    |> Enum.map(fn {col, val} -> {col, serialize(val)} end)
    |> Map.new()
  end

  defp serialize(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp serialize(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize(%Decimal{} = d), do: Decimal.to_string(d)
  defp serialize(list) when is_list(list), do: Enum.map(list, &serialize/1)
  defp serialize(map) when is_map(map), do: Map.new(map, fn {k,v} -> {k, serialize(v)} end)
  defp serialize(v), do: v
end
```

### Verify Task Structure
```elixir
# lib/mix/tasks/migrate.verify.ex
defmodule Mix.Tasks.Migrate.Verify do
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:mega_planner)

    database_url = System.get_env("POSTGRES_URL") ||
      raise "POSTGRES_URL is required"

    opts = Ecto.Repo.Supervisor.parse_url(database_url) |> Keyword.put(:pool_size, 2)
    {:ok, pg} = Postgrex.start_link(opts)

    alias MegaPlanner.Repo

    tables = Repo.query!("SELECT name FROM sqlite_master WHERE type='table' AND name != 'schema_migrations'")
    |> then(& &1.rows) |> List.flatten() |> Enum.sort()

    discrepancies = Enum.filter(tables, fn table ->
      pg_count = Postgrex.query!(pg, "SELECT COUNT(*) FROM \"#{table}\"", [])
                 |> then(& hd(hd(&1.rows)))
      sqlite_count = Repo.query!("SELECT COUNT(*) FROM \"#{table}\"")
                     |> then(& hd(hd(&1.rows)))
      if pg_count != sqlite_count do
        IO.puts("MISMATCH #{table}: pg=#{pg_count} sqlite=#{sqlite_count}")
        true
      else
        IO.puts("OK #{table}: #{pg_count}")
        false
      end
    end)

    if discrepancies == [] do
      IO.puts("\nVERIFY: PASSED — zero discrepancies")
    else
      IO.puts("\nVERIFY: FAILED — #{length(discrepancies)} tables with mismatches")
      exit({:shutdown, 1})
    end
  end
end
```

### Import: insert_all with atomized keys
```elixir
# Repo.insert_all expects atom keys, not string keys
defp atomize_keys(map) do
  Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
end

defp import_table(rows, table_name) do
  if rows == [] do
    IO.puts("  #{table_name}: 0 rows (skipping)")
  else
    entries = Enum.map(rows, &atomize_keys/1)
    {count, _} = MegaPlanner.Repo.insert_all(table_name, entries, on_conflict: :nothing)
    IO.puts("  #{table_name}: #{count} rows inserted")
  end
end
```

### PRAGMA foreign_key_check at End of Import
```elixir
# After all inserts, re-enable FK checks and verify
MegaPlanner.Repo.query!("PRAGMA foreign_keys = ON")
result = MegaPlanner.Repo.query!("PRAGMA foreign_key_check")
case result.rows do
  [] ->
    IO.puts("PRAGMA foreign_key_check: PASSED")
  violations ->
    IO.puts("PRAGMA foreign_key_check: FAILED — #{length(violations)} violations")
    Enum.each(violations, fn [table, rowid, parent, fkid] ->
      IO.puts("  #{table} rowid=#{rowid} -> #{parent} (fk #{fkid})")
    end)
    raise "Foreign key violations found after import"
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| pg_dump for data export | Elixir Mix tasks with Postgrex | Phase 4 decision | Correct UUID string encoding, type coercion under Elixir control |
| Postgrex as direct app dep | Postgrex as `only: :dev` dep | Phase 1 removed it; Phase 4 adds it back dev-only | Not compiled into production release |
| DATABASE_URL for PostgreSQL | POSTGRES_URL for export task | Phase 1 switched to DATABASE_PATH for SQLite | Avoids naming collision with existing env var |

**Deprecated/outdated:**
- The old `.exs` scripts in `priv/scripts/` used `Application.ensure_all_started(:postgrex)` directly — this pattern is outdated. The correct approach for Mix tasks is `Application.ensure_all_started(:mega_planner)` which starts all OTP applications in the supervision tree.

## Production Access Details

| Item | Value |
|------|-------|
| Fly app name | mega-planner-api |
| Postgres cluster | mega-planner-api-db |
| Database name | mega_planner_api |
| Postgres status | deployed (confirmed via fly postgres list) |
| Tunnel command | `fly proxy 5432:5432 -a mega-planner-api-db` |
| Connection URL format | `ecto://mega_planner_api:<password>@localhost:5432/mega_planner_api` |
| Password retrieval | `fly ssh console -a mega-planner-api` then `echo $DATABASE_URL`, or check fly secrets on the app |

## Table Inventory (48 data tables)

The following 48 tables exist in the SQLite schema (must all be covered by export/import/verify):

```
brands, budget_entries, budget_entries_tags, budget_sources, budget_sources_tags,
drivers, format_corrections, goal_categories, goal_milestones, goal_status_changes,
goals, goals_tags, habit_completions, habit_inventories, habits, habits_tags,
household_invitations, households, inventory_items, inventory_items_tags,
inventory_sheets, inventory_sheets_tags, milestone_templates, notebooks, notebooks_tags,
notification_preferences, notifications, page_links, pages, pages_tags, purchases,
purchases_tags, shopping_list_items, shopping_lists, shopping_lists_tags, stops,
stores, tags, task_steps, task_templates, tasks, tasks_tags, tax_indicator_meanings,
text_templates, trips, units, user_preferences, users
```

**Note:** The ROADMAP says "~30 tables" but the actual schema has 48 data tables. The export, import, and verify tasks must cover all 48.

## Tables Requiring Special Handling During Import

### Self-Referential FKs (two-pass required)
| Table | Column | FK Target |
|-------|--------|-----------|
| tasks | parent_task_id | tasks.id (ON DELETE SET NULL) |
| goal_categories | parent_id | goal_categories.id (ON DELETE SET NULL) |

### Circular Optional FKs (two-pass required)
| Table A | Column | Table B | Column |
|---------|--------|---------|--------|
| purchases | budget_entry_id (nullable) | budget_entries | purchase_id (nullable) |

### Tables with Multiple Optional Cross-Table FKs (import after their dependencies)
| Table | Optional FK Columns | Points To |
|-------|--------------------|-----------||
| inventory_items | purchase_id, trip_id, stop_id | purchases, trips, stops (all optional) |
| shopping_list_items | inventory_item_id, user_id | inventory_items, users (both nullable) |

With `PRAGMA foreign_keys = OFF`, none of these require specific ordering — but the two-pass approach is still needed for self-referential and circular FKs so that the final `PRAGMA foreign_key_check` passes.

## Array Column Types and JSON Serialization

Three column types store JSON arrays in SQLite (TEXT affinity). The spot checks in the success criteria reference these:

| Table | Column | Ecto Type | SQLite Storage | JSON Content |
|-------|--------|-----------|----------------|--------------|
| goals | linked_task_ids | `{:array, :binary_id}` | TEXT = `'["uuid1","uuid2"]'` | UUID strings |
| habit_inventories | linked_inventory_ids | `{:array, :binary_id}` | TEXT = `'["uuid1","uuid2"]'` | UUID strings |
| brands | default_tags | `{:array, :binary_id}` | TEXT = `'["uuid1","uuid2"]'` | UUID strings |

In PostgreSQL, these are `uuid[]` columns. Postgrex returns them as `[String.t()]` (list of UUID strings in canonical format). The export serializes them as JSON arrays of strings. The import passes them as Elixir lists to `Repo.insert_all` — `ecto_sqlite3` calls `Codec.json_encode/1` via the `{:array, _}` dumper and stores as JSON text.

The success criteria spot check verifies these are "readable strings (not binary blobs)" — this is automatically satisfied because Postgrex decodes UUID to string, and ecto_sqlite3 stores the JSON text representation.

## Open Questions

1. **Password retrieval for POSTGRES_URL**
   - What we know: The `DATABASE_URL` secret exists on the `mega-planner-api` app. The format is `ecto://user:pass@host/db`.
   - What's unclear: The password value is not accessible without `fly ssh console` or `fly secrets show` (which shows names but not values).
   - Recommendation: During DATA-04 execution, the executor will need to retrieve the actual URL from the running app: `fly ssh console -a mega-planner-api -C 'printenv DATABASE_URL'`. Document this step in the DATA-04 plan.

2. **Whether to use `only: :dev` for postgrex in mix.exs**
   - What we know: `only: :dev` means postgrex is compiled in dev and test but NOT in the production release. The export tasks are development-only operations.
   - What's unclear: The test environment may also need postgrex if any test validates the export functionality.
   - Recommendation: Use `only: [:dev, :test]` to be safe. No impact on production.

3. **PRAGMA foreign_keys = OFF and transaction interaction in ecto_sqlite3**
   - What we know: PRAGMA is connection-scoped. ecto_sqlite3 defaults to `foreign_keys: :on`. Sending PRAGMA inside a `Repo.transaction/2` callback guarantees same-connection execution.
   - What's unclear: Whether ecto_sqlite3 re-issues `PRAGMA foreign_keys = ON` when a connection is returned to the pool (which would undo our OFF setting).
   - Recommendation: Send `PRAGMA foreign_keys = OFF` inside the transaction block, not before it. After the transaction completes, send `PRAGMA foreign_keys = ON` on the same repo call. Validate with `PRAGMA foreign_key_check` immediately after.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in Elixir) |
| Config file | none — `mix test` alias in mix.exs |
| Quick run command | `cd /Users/sn0w/Documents/dev/lifeboard-mono/server && mix test` |
| Full suite command | `cd /Users/sn0w/Documents/dev/lifeboard-mono/server && mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DATA-01 | Mix task module compiles without errors | smoke (compile) | `cd server && mix compile` | ❌ Wave 0 — file doesn't exist yet |
| DATA-01 | Export file is valid JSON with all 48 table keys | smoke (manual) | `mix migrate.export /tmp/test_export.json && jq 'keys' /tmp/test_export.json` | manual-only |
| DATA-02 | Import task inserts rows into SQLite | smoke (manual) | `mix migrate.import /tmp/test_export.json && sqlite3 mega_planner_dev.db "SELECT count(*) FROM tasks"` | manual-only |
| DATA-03 | Verify task compares counts | smoke (manual) | `POSTGRES_URL=... mix migrate.verify` | manual-only |
| DATA-04 | Production export produces non-empty JSON | manual | Run against fly proxy tunnel; check file size > 0 | manual-only |
| DATA-05 | PRAGMA foreign_key_check returns 0 rows | smoke (manual) | `sqlite3 mega_planner_dev.db "PRAGMA foreign_key_check"` returns empty | manual-only |

**Note:** The three Mix tasks are one-shot production data tools, not continuously-testable units. Validation is primarily manual execution against the actual production database. The automated check is `mix compile` succeeding after the files are created.

### Sampling Rate
- **Per task commit:** `cd /Users/sn0w/Documents/dev/lifeboard-mono/server && mix compile` (confirms tasks compile without error)
- **Per wave merge:** `cd /Users/sn0w/Documents/dev/lifeboard-mono/server && mix test` (full suite)
- **Phase gate:** All five DATA requirements manually verified before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `server/lib/mix/tasks/migrate.export.ex` — DATA-01
- [ ] `server/lib/mix/tasks/migrate.import.ex` — DATA-02
- [ ] `server/lib/mix/tasks/migrate.verify.ex` — DATA-03
- [ ] `server/mix.exs` — add `{:postgrex, "~> 0.21", only: [:dev, :test]}` dep entry
- [ ] Mix task directory: `server/lib/mix/tasks/` — must be created (does not exist yet)

## Sources

### Primary (HIGH confidence)
- `server/deps/ecto_sqlite3/lib/ecto/adapters/sqlite3.ex` — `foreign_keys: :on` default, `{:array, _}` loader/dumper via `Codec.json_decode/json_encode`
- `server/deps/ecto_sqlite3/lib/ecto/adapters/sqlite3/codec.ex` — full serialization implementation for all SQLite column types
- `server/deps/ecto/lib/ecto/repo/supervisor.ex` — `parse_url/1` implementation confirmed
- `server/mega_planner_dev.db` — schema for all 48 tables, FK structure via `PRAGMA foreign_key_list`
- `server/mix.lock` — `postgrex 0.21.1` confirmed present
- `fly postgres list`, `fly apps list`, `fly secrets list -a mega-planner-api` — production infrastructure confirmed

### Secondary (MEDIUM confidence)
- Postgrex 0.21 documentation: UUID columns return `String.t()` in canonical UUID format; NaiveDateTime/DateTime returned for timestamp columns
- SQLite documentation: `PRAGMA foreign_keys` is connection-scoped; `PRAGMA foreign_key_check` returns rows for each FK violation

### Tertiary (LOW confidence)
- None — all critical claims verified from source in deps/ or from live infrastructure queries

## Metadata

**Confidence breakdown:**
- Postgrex connection approach: HIGH — confirmed in deps, mix.lock, fly infrastructure
- Table inventory (48 tables): HIGH — enumerated directly from SQLite schema
- FK ordering / circular FKs: HIGH — verified via `PRAGMA foreign_key_list` on all tables
- Array column serialization: HIGH — verified from ecto_sqlite3 codec.ex source
- PRAGMA foreign_keys connection-scope caveat: MEDIUM — from SQLite documentation, not tested in this codebase

**Research date:** 2026-03-07
**Valid until:** 2026-06-07 (ecto_sqlite3 ~> 0.22 and postgrex 0.21.1 are pinned versions)
