# Seed Trip Data Script
# Creates a complete shopping trip with store, stop, purchases,
# budget entries, and a calendar task.
#
# Usage: mix run --no-start .agent/skills/seed-trip-data/scripts/seed_trip.exs
# Output: server/seed_output.txt

# === CONFIGURATION ===
store_name = "Walmart Supercenter"
store_street = "3221 W 86th St"
store_city = "Indianapolis"
store_state = "IN"
store_zip = "46268"
trip_date = Date.utc_today()

purchases_config = [
  %{brand: "Great Value", item: "Whole Milk", count: 1, units: 1, unit_measurement: "gal", price: "3.48", store_code: "0011110008", item_name: "GV WHOLE MILK GAL"},
  %{brand: "Lay's", item: "Classic Chips", count: 2, units: 10, unit_measurement: "oz", price: "4.28", store_code: "0028400007", item_name: "LAYS CLASSIC 10OZ"}
]
# === END CONFIGURATION ===

# Boot Ecto
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:ecto)
MegaPlanner.Repo.start_link([])

import Ecto.Query
alias MegaPlanner.Repo
alias MegaPlanner.Accounts.User
alias MegaPlanner.Receipts.{Trip, Stop, Store, Purchase}
alias MegaPlanner.Budget
alias MegaPlanner.Calendar
alias MegaPlanner.Calendar.Task

# Use an Agent to accumulate output lines (avoid variable scoping issues in try/rescue)
{:ok, log} = Agent.start_link(fn -> [] end)
add_log = fn line ->
  Agent.update(log, fn lines -> lines ++ [line] end)
  IO.puts(line)
end

try do
  # 1. Get the first user
  user = Repo.one(from u in User, limit: 1)
  unless user, do: raise "No users found in the database"
  
  uid = user.id
  hid = user.household_id
  add_log.("USER_ID=#{uid}")
  add_log.("HOUSEHOLD_ID=#{hid}")

  # 2. Find or create the store
  existing_store = Repo.one(
    from s in Store,
      where: s.household_id == ^hid,
      where: s.name == ^store_name and s.city == ^store_city,
      limit: 1
  )

  store = case existing_store do
    nil ->
      {:ok, s} = %Store{}
        |> Store.changeset(%{
          "name" => store_name,
          "street" => store_street,
          "city" => store_city,
          "state" => store_state,
          "zip_code" => store_zip,
          "household_id" => hid,
          "tax_rate" => "0.07"
        })
        |> Repo.insert()
      add_log.("STORE_ID=#{s.id} (created: #{store_name})")
      s
    s ->
      add_log.("STORE_ID=#{s.id} (existing: #{store_name})")
      s
  end

  # 3. Create the trip
  trip_start = DateTime.new!(trip_date, ~T[12:00:00], "Etc/UTC")
  {:ok, trip} = %Trip{}
    |> Trip.changeset(%{
      "trip_start" => trip_start,
      "household_id" => hid,
      "user_id" => uid,
      "notes" => "Seeded trip"
    })
    |> Repo.insert()
  add_log.("TRIP_ID=#{trip.id} (#{trip_start})")

  # 4. Create the stop
  {:ok, stop} = %Stop{}
    |> Stop.changeset(%{
      "trip_id" => trip.id,
      "store_id" => store.id,
      "store_name" => store_name,
      "position" => 0
    })
    |> Repo.insert()
  add_log.("STOP_ID=#{stop.id}")

  # 5. Get or create the budget source for this store
  {:ok, source} = Budget.get_or_create_source_for_store(hid, uid, store_name)
  source_id = if source, do: source.id, else: nil
  add_log.("BUDGET_SOURCE_ID=#{inspect(source_id)}")

  # 6. Create purchases with budget entries
  Enum.each(purchases_config, fn p ->
    # Create the budget entry first (required FK for purchase)
    {:ok, entry} = Budget.create_entry(%{
      "household_id" => hid,
      "user_id" => uid,
      "date" => trip_date,
      "amount" => p.price,
      "type" => "expense",
      "notes" => "Purchase: #{p.brand} - #{p.item}",
      "source_id" => source_id
    })

    # Create the purchase
    {:ok, purchase} = %Purchase{}
      |> Purchase.changeset(%{
        "brand" => p.brand,
        "item" => p.item,
        "count" => p.count,
        "count_unit" => nil,
        "units" => p.units,
        "unit_measurement" => p.unit_measurement,
        "price_per_count" => p.price,
        "total_price" => p.price,
        "store_code" => p.store_code,
        "item_name" => p.item_name,
        "usage_mode" => "count",
        "taxable" => true,
        "tax_rate" => "0.07",
        "household_id" => hid,
        "stop_id" => stop.id,
        "budget_entry_id" => entry.id
      })
      |> Repo.insert()

    # Back-link budget entry to purchase
    Budget.update_entry(entry, %{"purchase_id" => purchase.id})

    add_log.("PURCHASE_ID=#{purchase.id} (#{p.brand} #{p.item} — $#{p.price})")
  end)

  # 7. Create the calendar task linked to this trip
  #    Reload the trip with all preloads so generate_trip_task_title works
  trip_full = MegaPlanner.Receipts.get_trip(trip.id)
  title = "Seed: " <> Calendar.generate_trip_task_title(trip_full)

  {:ok, task} = Calendar.create_task(%{
    "title" => title,
    "date" => Date.to_iso8601(trip_date),
    "task_type" => "trip",
    "status" => "not_started",
    "household_id" => hid,
    "user_id" => uid,
    "trip_id" => trip.id
  })
  add_log.("TASK_ID=#{task.id} (\"#{title}\" on #{trip_date})")
  add_log.("")
  add_log.("=== SEED COMPLETE ===")
rescue
  e ->
    add_log.("EXCEPTION=#{Exception.message(e)}")
    add_log.("STACK=#{inspect(__STACKTRACE__ |> Enum.take(3))}")
end

# Write output
all_lines = Agent.get(log, fn lines -> lines end)
File.write!("seed_output.txt", Enum.join(all_lines, "\n") <> "\n")
