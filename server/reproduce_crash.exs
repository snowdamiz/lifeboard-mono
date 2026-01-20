
# reproduce_crash.exs
alias MegaPlanner.Repo
alias MegaPlanner.Households.Household
alias MegaPlanner.Accounts.User
alias MegaPlanner.Receipts
alias MegaPlanner.Inventory
import Ecto.Query

Process.put(:user_id, nil)
Process.put(:household_id, nil)

household = Repo.one(from h in Household, limit: 1)
user = Repo.one(from u in User, where: u.household_id == ^household.id, limit: 1)

IO.puts "User: #{user.email}, Household: #{household.name}"

# 1. Create Store named "1"
{:ok, store} = 
  case Repo.get_by(Receipts.Store, household_id: household.id, name: "1") do
    nil -> Receipts.create_store(%{name: "1", household_id: household.id, state: "IN"})
    store -> {:ok, store}
  end
IO.puts "Store '1' ID: #{store.id}"

# 2. Create Inventory Sheet "1"
{:ok, sheet} = 
  case Repo.get_by(Inventory.Sheet, household_id: household.id, name: "1") do
    nil -> Inventory.create_sheet(%{name: "1", household_id: household.id, user_id: user.id})
    sheet -> {:ok, sheet}
  end
IO.puts "Sheet '1' ID: #{sheet.id}"

# 3. Create Inventory Item "1" in "1" sheet, Brand "1", Store "1", Qty 1
# Delete existing to start clean
Repo.delete_all(from i in Inventory.Item, where: i.sheet_id == ^sheet.id and i.name == "1")

{:ok, inv_item} = Inventory.create_item(%{
  sheet_id: sheet.id,
  name: "1",
  brand: "1",
  store: "1", # This sets the text field 'store' to "1"
  quantity: 1,
  unit_of_measure: "box"
})
IO.puts "Inventory Item '1' Created with Qty 1. Store field is '#{inv_item.store}'"

# 4. Create Purchase "1", Brand "1", at Store "1" (via Stop)
# Create Trip
{:ok, trip} = Receipts.create_trip(%{household_id: household.id, user_id: user.id, trip_start: DateTime.utc_now()})
{:ok, stop} = Receipts.create_stop(%{trip_id: trip.id, store_id: store.id, position: 1})

IO.puts "Simulating Purchase..."
try do
  {:ok, purchase} = Receipts.create_purchase(%{
    "brand" => "1",
    "item" => "1",
    "total_price" => "1.00",
    "units" => "1",
    "count" => "1",
    "household_id" => household.id,
    "user_id" => user.id,
    "stop_id" => stop.id,
    "date" => Date.utc_today(),
    "unit_measurement" => "box",
    "taxable" => true
  })
  IO.puts "Purchase Created: #{purchase.id}"
  
  # Check inventory
  reloaded_item = Repo.get(Inventory.Item, inv_item.id)
  IO.puts "Inventory Item Qty is now: #{reloaded_item.quantity}"
  
  if reloaded_item.quantity == 2 do
    IO.puts "SUCCESS: Quantity incremented."
  else
    IO.puts "FAILURE: Quantity did NOT increment."
  end
  
rescue
  e -> 
    IO.puts "\nCRASH DETECTED!"
    IO.inspect e
    IO.puts Exception.format(:error, e, __STACKTRACE__)
end
