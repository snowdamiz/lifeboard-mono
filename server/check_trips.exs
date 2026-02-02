# Check trip data - output to file
alias MegaPlanner.Repo
import Ecto.Query

trips = Repo.all(
  from t in MegaPlanner.Receipts.Trip,
    preload: [:stops],
    order_by: [desc: t.inserted_at]
)

output = Enum.map(trips, fn t ->
  stop_info = Enum.map(t.stops, fn s ->
    "    Stop: time_arrived=#{s.time_arrived}, store=#{s.store_name}"
  end) |> Enum.join("\n")
  
  "Trip ID: #{t.id}\n  trip_start: #{t.trip_start}\n#{stop_info}"
end) |> Enum.join("\n\n")

File.write!("trip_check_output.txt", output)
IO.puts("Written to trip_check_output.txt")
