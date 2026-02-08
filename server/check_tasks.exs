import Ecto.Query
tasks = MegaPlanner.Repo.all(from t in "tasks", select: %{title: t.title, date: t.date, status: t.status})
IO.puts("Total tasks: #{Enum.count(tasks)}")
tasks |> Enum.take(15) |> Enum.each(fn t ->
  IO.puts("  #{t.title} | date: #{t.date} | status: #{t.status}")
end)
