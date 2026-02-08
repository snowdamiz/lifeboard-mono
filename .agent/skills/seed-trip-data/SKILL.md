---
name: Seed Trip Data
description: Create backend DB entries to simulate a user entering a complete shopping trip with store, stop, purchases, budget entries, and calendar task. Use this to verify calendar display, budget rendering, or inventory flow without going through the UI.
---

# Seed Trip Data

This skill creates a complete shopping trip in the database, including all related entities, to simulate what happens when a user enters a trip through the UI. This is useful for:

- **Debugging calendar display** — verify tasks show up when data definitely exists in the DB
- **Testing budget rendering** — create purchase data with budget entries
- **Testing inventory flow** — create purchases that can be transferred to inventory
- **Reproducing bugs** — create specific data conditions that are hard to set up manually

## How to Use

### 1. Run the seed script

The seed script is located at `.agent/skills/seed-trip-data/scripts/seed_trip.exs`. It creates:

1. **Store** — a store record (e.g., "Walmart Supercenter")
2. **Trip** — a trip with `trip_start` set to today at noon UTC
3. **Stop** — links the trip to the store
4. **Budget Source** — auto-created for the store
5. **Purchases** (2 items) — each with a corresponding budget entry
6. **Calendar Task** — a `task_type: "trip"` task linked to the trip via `trip_id`

Run it from the `server/` directory:

```powershell
cd c:\Users\yurlo\.gemini\antigravity\scratch\lifeboard-mono\server
mix run --no-start "c:\Users\yurlo\.gemini\antigravity\scratch\lifeboard-mono\.agent\skills\seed-trip-data\scripts\seed_trip.exs"
```

Results are written to `server/seed_output.txt`. Read it to confirm success:

```powershell
Get-Content seed_output.txt
```

### 2. Customize the data

The script is parameterized at the top. You can edit these values before running:

```elixir
# === CONFIGURATION ===
store_name = "Walmart Supercenter"
store_city = "Indianapolis"
store_state = "IN"
trip_date = Date.utc_today()  # Change to a specific date like ~D[2026-02-10]

purchases = [
  %{brand: "Great Value", item: "Whole Milk", count: 1, price: "3.48", store_code: "0011110008"},
  %{brand: "Lay's", item: "Classic Chips", count: 2, price: "4.28", store_code: "0028400007"}
]
```

### 3. Verify the data

After running the seed script, verify the data exists:

```powershell
# Quick count check
mix run --no-start -e "
  MegaPlanner.Repo.start_link([])
  import Ecto.Query
  IO.puts(\"Tasks: #{MegaPlanner.Repo.aggregate(from(t in \"tasks\"), :count)}\")
  IO.puts(\"Trips: #{MegaPlanner.Repo.aggregate(from(t in \"trips\"), :count)}\")
  IO.puts(\"Purchases: #{MegaPlanner.Repo.aggregate(from(p in \"purchases\"), :count)}\")
"
```

Then refresh the calendar in the browser to confirm the task appears.

### 4. Clean up seeded data

To remove all seeded data, delete the task (which cascades to the trip via the `delete_task` function):

```powershell
# Delete by task title pattern
mix run --no-start -e "
  MegaPlanner.Repo.start_link([])
  import Ecto.Query
  alias MegaPlanner.Calendar.Task
  tasks = MegaPlanner.Repo.all(from t in Task, where: ilike(t.title, \"%Seed:%\"))
  Enum.each(tasks, fn t -> MegaPlanner.Calendar.delete_task(t) end)
  IO.puts(\"Deleted #{length(tasks)} seeded tasks\")
"
```

## Entity Relationship Chain

```
Store
  └── Stop (belongs_to Trip, belongs_to Store)
        └── Purchase (belongs_to Stop, belongs_to BudgetEntry)
              └── BudgetEntry (belongs_to Purchase — bidirectional FK)

Trip (has_many Stops)
  └── Task (belongs_to Trip via trip_id, task_type: "trip")
```

## Important Notes

- The script uses **the first user** in the database and their `household_id`.
- Purchases require a `budget_entry_id` (validated as required in the changeset), so budget entries are created first.
- The calendar task is linked to the trip via `trip_id` and has `task_type: "trip"`.
- The task's `date` field matches the trip's `trip_start` date.
- Budget entries have their `purchase_id` back-linked after the purchase is created.
- Store uniqueness is checked by `(household_id, name, street, city)` — the script uses `find_or_create` logic to avoid duplicates.
