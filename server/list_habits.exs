alias MegaPlanner.Repo
alias MegaPlanner.Goals.{Habit, HabitCompletion, HabitInventory}

IO.puts("=== HABITS ===")
habits = Repo.all(Habit)
Enum.each(habits, fn h ->
  IO.puts("ID: #{h.id}")
  IO.puts("  Name: #{h.name}")
  IO.puts("  Created: #{h.inserted_at}")
  IO.puts("  Inventory ID: #{h.inventory_id}")
  IO.puts("")
end)
IO.puts("Total habits: #{length(habits)}")

IO.puts("")
IO.puts("=== HABIT COMPLETIONS ===")
completions = Repo.all(HabitCompletion)
IO.puts("Total completions: #{length(completions)}")

IO.puts("")
IO.puts("=== HABIT INVENTORIES ===")
inventories = Repo.all(HabitInventory)
Enum.each(inventories, fn i ->
  IO.puts("ID: #{i.id} - Name: #{i.name}")
end)
