# Test the changeset directly
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto_sql)
{:ok, _} = MegaPlanner.Repo.start_link()

alias MegaPlanner.Goals.Habit

# Simulate what the controller receives
attrs = %{
  "name" => "Test Habit",
  "description" => "Test Desc",
  "frequency" => "daily",
  "scheduled_time" => "12:58",
  "duration_minutes" => "30",
  "color" => "#10b981",
  "user_id" => "00000000-0000-0000-0000-000000000001",
  "household_id" => "00000000-0000-0000-0000-000000000001"
}

IO.puts("=== TESTING CHANGESET ===")
IO.puts("Input attrs:")
IO.inspect(attrs)

changeset = Habit.changeset(%Habit{}, attrs)

IO.puts("\nChangeset valid?: #{changeset.valid?}")
IO.puts("\nChangeset changes:")
IO.inspect(changeset.changes)

IO.puts("\nChangeset errors:")
IO.inspect(changeset.errors)
