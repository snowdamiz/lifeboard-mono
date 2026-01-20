
alias MegaPlanner.Repo
alias MegaPlanner.Receipts.{Trip, Driver}
alias MegaPlanner.Receipts

IO.puts("\n--- Drivers ---")
drivers = Repo.all(Driver)
Enum.each(drivers, fn d -> IO.puts("#{d.id} - #{d.name}") end)

driver = List.first(drivers)

if driver do
  IO.puts("\n--- Attempting Update with Driver #{driver.id} ---")
  
  # Fetch a trip (any trip)
  trip = Repo.one(Trip)
  
  if trip do
    IO.puts("Updating Trip #{trip.id}...")
    
    # Manually invoke the changeset function to see if it handles the constraint
    changeset = Trip.changeset(trip, %{driver_id: driver.id})
    
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
