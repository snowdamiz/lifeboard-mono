
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

store = Repo.get_by(Store, name: "1")

if store do
  IO.puts("\n--- STORE DEBUG INFO ---")
  IO.puts("ID: #{store.id}")
  IO.puts("Name: #{store.name}")
  IO.inspect(store.store_code, label: "Store Code")
  IO.puts("------------------------\n")
else
  IO.puts("\n--- STORE '1' NOT FOUND ---\n")
end
