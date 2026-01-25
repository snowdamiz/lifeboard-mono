
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
alias MegaPlanner.Receipts.Store
import Ecto.Query

IO.puts("\n--- ALL STORES ---")
Store
|> order_by([s], s.name)
|> Repo.all()
|> Enum.each(fn s ->
  IO.puts("ID: #{s.id} | Name: '#{s.name}' | Code: '#{s.store_code}'")
end)
IO.puts("------------------\n")
