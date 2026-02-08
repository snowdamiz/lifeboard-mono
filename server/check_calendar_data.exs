Application.put_env(:mega_planner, MegaPlannerWeb.Endpoint, [http: [port: 0], server: false, url: [host: "localhost"]])
Application.put_env(:phoenix, :serve_endpoints, false)
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:postgrex)
children = [MegaPlanner.Repo]
Supervisor.start_link(children, strategy: :one_for_one, name: :check_sup)

alias MegaPlanner.Repo
import Ecto.Query

results = Repo.all(from t in "tasks", select: %{id: t.id, title: t.title, date: t.date, trip_id: t.trip_id, task_type: t.task_type}, order_by: [desc: t.inserted_at], limit: 10)

output = Enum.map_join(results, "\n", fn t ->
  "#{t.date} | #{t.task_type} | #{t.title} | trip_id=#{t.trip_id || "nil"}"
end)

File.write!("db_check_results.txt", "=== RECENT TASKS ===\n#{output}\n\nTotal: #{Repo.one(from t in "tasks", select: count(t.id))}\n\n")

# Tasks this week
week = Repo.all(from t in "tasks", where: t.date >= ^~D[2026-02-02] and t.date <= ^~D[2026-02-08], select: %{id: t.id, title: t.title, date: t.date, trip_id: t.trip_id, task_type: t.task_type}, order_by: [asc: t.date])

week_output = Enum.map_join(week, "\n", fn t ->
  "#{t.date} | #{t.task_type} | #{t.title} | trip_id=#{t.trip_id || "nil"}"
end)

File.write!("db_check_results.txt", File.read!("db_check_results.txt") <> "=== TASKS THIS WEEK (Feb 2-8) ===\nFound: #{length(week)}\n#{week_output}\n\n")

# Recent trips
trips = Repo.all(from t in "trips", select: %{id: t.id, trip_start: t.trip_start, household_id: t.household_id}, order_by: [desc: t.inserted_at], limit: 10)

trips_output = Enum.map_join(trips, "\n", fn t ->
  "#{t.trip_start} | id=#{t.id}"
end)

File.write!("db_check_results.txt", File.read!("db_check_results.txt") <> "=== RECENT TRIPS ===\nTotal: #{Repo.one(from t in "trips", select: count(t.id))}\n#{trips_output}\n\n")

# Tasks with trip_id
trip_tasks = Repo.all(from t in "tasks", where: not is_nil(t.trip_id), select: %{id: t.id, title: t.title, date: t.date, trip_id: t.trip_id, task_type: t.task_type}, order_by: [desc: t.inserted_at], limit: 10)

trip_output = Enum.map_join(trip_tasks, "\n", fn t ->
  "#{t.date} | #{t.task_type} | #{t.title} | trip_id=#{t.trip_id}"
end)

File.write!("db_check_results.txt", File.read!("db_check_results.txt") <> "=== TASKS WITH TRIP_ID ===\nFound: #{length(trip_tasks)}\n#{trip_output}\n")

IO.puts("Results written to db_check_results.txt")
