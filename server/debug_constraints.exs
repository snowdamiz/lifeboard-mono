
# Start dependencies
{:ok, _} = Application.ensure_all_started(:telemetry)
{:ok, _} = Application.ensure_all_started(:ecto)
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:jason)

# Load the main app config
Application.load(:mega_planner)

# Start Repo manually
{:ok, _} = MegaPlanner.Repo.start_link()

alias MegaPlanner.Repo

IO.puts("\n--- CHECKING FOREIGN KEYS FOR inventory_items ---")

sql = """
SELECT
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
    JOIN information_schema.referential_constraints AS rc
      ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND ccu.table_name = 'inventory_items';
"""

{:ok, result} = Ecto.Adapters.SQL.query(Repo, sql, [])

IO.puts(String.pad_trailing("TABLE", 30) <> String.pad_trailing("COLUMN", 30) <> "ON DELETE")
IO.puts(String.duplicate("-", 80))

Enum.each(result.rows, fn [table, col, _, _, rule] ->
  IO.puts(String.pad_trailing(table, 30) <> String.pad_trailing(col, 30) <> rule)
end)
