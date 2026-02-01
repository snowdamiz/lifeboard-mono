Application.put_env(:mega_planner, :start_web, false)
Application.put_env(:swoosh, :serve_mailbox, false)

alias MegaPlanner.{Repo, Goals}
alias MegaPlanner.Goals.{Habit, HabitInventory}
import Ecto.Query

# Get a user ID
user = Repo.one(from u in MegaPlanner.Accounts.User, limit: 1)

if user do
  user_id = user.id
  IO.puts("Using user: #{user.email}")
  
  # Clear all existing habits and inventories
  Repo.delete_all(from h in Habit, where: h.user_id == ^user_id)
  Repo.delete_all(from i in HabitInventory, where: i.user_id == ^user_id)
  IO.puts("Cleared all habits and inventories")
  
  # Create whole day inventory
  {:ok, whole_day_inv} = Goals.create_habit_inventory(%{
    name: "Morning Routine",
    color: "#10b981",
    coverage_mode: "whole_day",
    user_id: user_id
  })
  IO.puts("Created whole day inventory: #{whole_day_inv.name}")
  
  # Create partial day inventory linked to whole day
  {:ok, partial_inv} = Goals.create_habit_inventory(%{
    name: "Work Focus",
    color: "#3b82f6",
    coverage_mode: "partial_day",
    linked_inventory_id: whole_day_inv.id,
    user_id: user_id
  })
  IO.puts("Created partial day inventory linked to whole day: #{partial_inv.name}")
  
  # Create 2 habits in whole day inventory (early morning times)
  {:ok, habit1} = Goals.create_habit(%{
    name: "Wake Up Early",
    description: "Start the day at 6 AM",
    color: "#10b981",
    frequency: "daily",
    days_of_week: [0, 1, 2, 3, 4, 5, 6],
    scheduled_time: "06:00",
    duration_minutes: 30,
    inventory_id: whole_day_inv.id,
    user_id: user_id
  })
  IO.puts("Created habit: #{habit1.name}")
  
  {:ok, habit2} = Goals.create_habit(%{
    name: "Morning Exercise",
    description: "30 minute workout",
    color: "#06b6d4",
    frequency: "daily",
    days_of_week: [0, 1, 2, 3, 4, 5, 6],
    scheduled_time: "07:00",
    duration_minutes: 45,
    inventory_id: whole_day_inv.id,
    user_id: user_id
  })
  IO.puts("Created habit: #{habit2.name}")
  
  # Create 2 habits in partial day inventory (work hours)
  {:ok, habit3} = Goals.create_habit(%{
    name: "Deep Work Session",
    description: "Focused coding time",
    color: "#3b82f6",
    frequency: "daily",
    days_of_week: [1, 2, 3, 4, 5],
    scheduled_time: "09:00",
    duration_minutes: 120,
    inventory_id: partial_inv.id,
    user_id: user_id
  })
  IO.puts("Created habit: #{habit3.name}")
  
  {:ok, habit4} = Goals.create_habit(%{
    name: "Team Standup",
    description: "Daily sync meeting",
    color: "#8b5cf6",
    frequency: "daily",
    days_of_week: [1, 2, 3, 4, 5],
    scheduled_time: "10:00",
    duration_minutes: 15,
    inventory_id: partial_inv.id,
    user_id: user_id
  })
  IO.puts("Created habit: #{habit4.name}")
  
  IO.puts("\n=== Setup Complete ===")
  IO.puts("Created 2 habits in whole day inventory (Morning Routine)")
  IO.puts("Created 2 habits in partial day inventory (Work Focus) linked to Morning Routine")
else
  IO.puts("No user found!")
end
