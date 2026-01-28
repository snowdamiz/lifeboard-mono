Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto_sql)
{:ok, _} = MegaPlanner.Repo.start_link([])

alias MegaPlanner.{Repo, Goals.Habit, Goals.HabitCompletion}
import Ecto.Query

habit = Repo.one(from h in Habit, limit: 1)

if habit do
  IO.puts("Using habit: #{habit.name}")
  today = Date.utc_today()

  Enum.each(0..9, fn days_ago ->
    date = Date.add(today, -days_ago)
    existing = Repo.one(from c in HabitCompletion, where: c.habit_id == ^habit.id and c.date == ^date)
    
    unless existing do
      status = if :rand.uniform(10) <= 8, do: "completed", else: "skipped"
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      
      # Always set completed_at (NOT NULL constraint)
      Repo.insert!(%HabitCompletion{
        habit_id: habit.id, 
        date: date, 
        status: status, 
        completed_at: now
      })
      IO.puts("Created #{status} for #{date}")
    else
      IO.puts("Already exists for #{date}")
    end
  end)

  count = Repo.aggregate(HabitCompletion, :count, :id)
  IO.puts("Total completions: #{count}")
else
  IO.puts("No habits found!")
end
