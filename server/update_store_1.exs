
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
import Ecto.Changeset

store = Repo.get_by(Store, name: "1")

if store do
  IO.puts("Updating Store '1' with code 'CODE1'...")
  store
  |> change(store_code: "CODE1")
  |> Repo.update()
  |> case do
    {:ok, updated_store} ->
      IO.puts("Success! Store Code is now: #{updated_store.store_code}")
    {:error, changeset} ->
      IO.inspect(changeset.errors, label: "Error updating store")
  end
else
  IO.puts("Store '1' not found, cannot update.")
end
