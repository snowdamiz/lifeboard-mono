# server/reproduce_trip_merge.exs

alias MegaPlanner.{Repo, Inventory, Receipts, Budget}
alias MegaPlanner.Inventory.{Sheet, Item}
alias MegaPlanner.Receipts.{Trip, Stop, Purchase}
import Ecto.Query


# 0. Start Repo
{:ok, _} = MegaPlanner.Repo.start_link()
IO.puts("Repo started.")

# 1. Setup Data
IO.puts("\n=== Setup ===")
# Get a user (assuming seeds ran)
user = Repo.one(from u in MegaPlanner.Accounts.User, limit: 1)
household_id = user.household_id
IO.puts("User matches: #{user.email}")

# Ensure "Purchases" sheet exists
{:ok, purchases_sheet} = Inventory.get_or_create_purchases_sheet(household_id, user.id)
IO.puts("Purchases Sheet ID: #{purchases_sheet.id}")

# Create/Get "Pantry" sheet
pantry_sheet = case Repo.get_by(Sheet, household_id: household_id, name: "Pantry") do
  nil -> {:ok, s} = Inventory.create_sheet(%{household_id: household_id, name: "Pantry", user_id: user.id}); s
  s -> s
end
IO.puts("Pantry Sheet ID: #{pantry_sheet.id}")

# Create Existing Item in Pantry
IO.puts("\n--- Creating 'Existing Item' in Pantry ---")
item_name = "MergeTest Item #{System.unique_integer()}"
{:ok, existing_item} = Inventory.create_item(%{
  name: item_name,
  brand: "Generic",
  quantity: 5,
  sheet_id: pantry_sheet.id
})
IO.puts("Created Item '#{item_name}' in Pantry (Qty: 5)")

# 2. Simulate Trip Purchase
IO.puts("\n--- Simulating Trip Purchase ---")
{:ok, trip} = Receipts.create_trip(%{
  trip_start: DateTime.utc_now(),
  household_id: household_id,
  driver_id: nil
})
{:ok, stop} = Receipts.create_stop(%{
  trip_id: trip.id,
  position: 0,
  store_name: "Test Store"
})

IO.puts("Created Trip & Stop")

# Create Purchase for the SAME item name
# This calls `create_item_from_purchase` internally
{:ok, purchase} = Receipts.create_purchase(%{
  "household_id" => household_id,
  "user_id" => user.id,
  "brand" => "Generic",
  "item" => item_name,
  "count" => 2,
  "total_price" => 10.00,
  "date" => Date.utc_today(),
  "stop_id" => stop.id
})
IO.puts("Created Purchase for '#{item_name}' (Qty: 2)")

# 3. Validation
IO.puts("\n--- Validating Results ---")

# Check Pantry Item
updated_pantry_item = Repo.get(Item, existing_item.id)
IO.puts("Pantry Item Quantity: #{updated_pantry_item.quantity} (Expected: 5, Actual if Bug: 7)")

# Check Purchases Sheet
new_purchases_item = Repo.one(from i in Item, 
  where: i.sheet_id == ^purchases_sheet.id and i.name == ^item_name
)

if new_purchases_item do
  IO.puts("Purchases Sheet Item: FOUND (ID: #{new_purchases_item.id}, Qty: #{new_purchases_item.quantity})")
  IO.puts("\nRESULT: FIXED / WORKING AS DESIRED (Staged in Purchases)")
else
  IO.puts("Purchases Sheet Item: NOT FOUND")
  IO.puts("\nRESULT: BUG REPRODUCED (Merged directly to Pantry)")
end

# Cleanup?
