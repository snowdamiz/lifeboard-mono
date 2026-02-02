# Repair script to fix trip_start times that are set to midnight
# This updates trips to use the actual receipt time from stops

alias MegaPlanner.Repo
alias MegaPlanner.Receipts.Trip
alias MegaPlanner.Receipts.Stop
import Ecto.Query

IO.puts("Starting trip time repair...")

# Find all trips with trip_start at midnight (00:00:00)
trips = Repo.all(
  from t in Trip,
    where: not is_nil(t.trip_start),
    preload: [stops: :store]
)

updated_count = Enum.reduce(trips, 0, fn trip, count ->
  # Check if trip is at midnight
  trip_time = DateTime.to_time(trip.trip_start)
  is_midnight = trip_time == ~T[00:00:00]
  
  if is_midnight and length(trip.stops) > 0 do
    # Get the first stop's time_arrived (this should have the receipt time)
    first_stop = List.first(trip.stops)
    
    if first_stop && first_stop.time_arrived do
      # Combine the trip's date with the stop's time
      trip_date = DateTime.to_date(trip.trip_start)
      new_trip_start = DateTime.new!(trip_date, first_stop.time_arrived, "Etc/UTC")
      
      IO.puts("Updating trip #{trip.id}: #{trip.trip_start} -> #{new_trip_start}")
      
      case Repo.update(Trip.changeset(trip, %{trip_start: new_trip_start})) do
        {:ok, _} -> 
          count + 1
        {:error, changeset} -> 
          IO.puts("  Failed: #{inspect(changeset.errors)}")
          count
      end
    else
      count
    end
  else
    count
  end
end)

IO.puts("\nRepair complete. Updated #{updated_count} trips.")
