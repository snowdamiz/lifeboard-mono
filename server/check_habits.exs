Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto_sql)
{:ok, _} = MegaPlanner.Repo.start_link()

{:ok, result} = Ecto.Adapters.SQL.query(
  MegaPlanner.Repo,
  "SELECT name, scheduled_time, duration_minutes FROM habits"
)

IO.puts("=== HABITS IN DATABASE ===")
IO.puts("Total: #{length(result.rows)} habits")
Enum.each(result.rows, fn [name, scheduled_time, duration_minutes] ->
  IO.puts("Name: #{name}")
  IO.puts("  scheduled_time: #{inspect(scheduled_time)}")
  IO.puts("  duration_minutes: #{inspect(duration_minutes)}")
end)
