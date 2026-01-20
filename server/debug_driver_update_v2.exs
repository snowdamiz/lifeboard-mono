
# Start dependencies
[:logger, :crypto, :ssl, :postgrex, :ecto, :ecto_sql]
|> Enum.each(&Application.ensure_all_started/1)

Application.load(:mega_planner)

# Manually start the Repo (needed for DB access)
{:ok, _} = MegaPlanner.Repo.start_link()

alias MegaPlanner.Repo
alias MegaPlanner.Receipts.{Trip, Driver}

IO.puts("\n--- Drivers ---")
drivers = Repo.all(Driver)
Enum.each(drivers, fn d -> IO.puts("#{d.id} - #{d.name}") end)

driver = List.first(drivers)

if driver do
  IO.puts("\n--- Attempting Update with Driver #{driver.id} ---")
  
  # Fetch a trip
  trip = Repo.all(Trip) |> List.first()
  
  if trip do
    IO.puts("Updating Trip #{trip.id}...")
    
    # Check if code has the constraint logic
    changeset = Trip.changeset(trip, %{driver_id: driver.id})
    IO.inspect(changeset.constraints, label: "Changeset Constraints")
    
    # Try the update
    try do
      case Repo.update(changeset) do
        {:ok, updated} -> IO.puts("SUCCESS: Trip updated with driver #{updated.driver_id}")
        {:error, cs} -> 
          IO.puts("FAILURE (Validation):")
          IO.inspect(cs.errors)
      end
    rescue
      e -> 
        IO.puts("CRASH (Exception):")
        IO.inspect(e)
    end
  else
    IO.puts("No trips found.")
  end
else
  IO.puts("No drivers found.")
end
