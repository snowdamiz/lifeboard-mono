
# debug_purchase_inventory.exs
alias MegaPlanner.Repo
alias MegaPlanner.Households.Household
alias MegaPlanner.Accounts.User
alias MegaPlanner.Receipts
alias MegaPlanner.Inventory
import Ecto.Query

Process.put(:user_id, nil)
Process.put(:household_id, nil)

defmodule DebugHelper do
  def setup do
    household = Repo.one(from h in Household, limit: 1)
    user = Repo.one(from u in User, where: u.household_id == ^household.id, limit: 1)
    
    if is_nil(household) or is_nil(user) do
      IO.puts "No household or user found. Please ensure DB is seeded."
      System.halt(1)
    end
    
    IO.puts "Using Household: #{household.name} (#{household.id})"
    IO.puts "Using User: #{user.email} (#{user.id})"
    
    {household, user}
  end
  
  def create_store(household, name) do
    # Try to find existing first
    case Repo.get_by(MegaPlanner.Receipts.Store, household_id: household.id, name: name) do
      nil ->
        {:ok, store} = Receipts.create_store(%{
          name: name,
          household_id: household.id,
          state: "IN"
        })
        store
      store -> store
    end
  end

  def create_sheet(household, user, name) do
     case Repo.get_by(MegaPlanner.Inventory.Sheet, household_id: household.id, name: name) do
       nil ->
          {:ok, sheet} = Inventory.create_sheet(%{
            name: name,
            household_id: household.id,
            user_id: user.id
          })
          sheet
       sheet -> sheet
     end
  end
  
  def create_inventory_item(sheet, name, brand, store_name, quantity) do
    # Check if exists
    existing = Repo.one(from i in Inventory.Item, where: i.sheet_id == ^sheet.id and i.name == ^name and i.brand == ^brand)
    
    if existing do
       # Reset quantity
       {:ok, item} = Inventory.update_item(existing, %{quantity: quantity, store: store_name})
       item
    else
      {:ok, item} = Inventory.create_item(%{
        sheet_id: sheet.id,
        name: name,
        brand: brand,
        store: store_name,
        quantity: quantity
      })
      item
    end
  end
end

{household, user} = DebugHelper.setup()

# Use fixed names for reproducibility and easier cleanup
store_a_name = "Debug Store A"
store_b_name = "Debug Store B"
item_name = "Debug Item"
brand_name = "Debug Brand"
sheet_name = "Debug Inventory"

# Cleanup items to ensure clean state
# Find sheets
debug_sheet = Repo.get_by(Inventory.Sheet, household_id: household.id, name: sheet_name)
purchases_sheet = Repo.get_by(Inventory.Sheet, household_id: household.id, name: "Purchases")

if debug_sheet do
  Repo.delete_all(from i in Inventory.Item, where: i.sheet_id == ^debug_sheet.id and i.name == ^item_name)
end
if purchases_sheet do
  Repo.delete_all(from i in Inventory.Item, where: i.sheet_id == ^purchases_sheet.id and i.name == ^item_name)
end

IO.puts "Creating/Getting Stores..."
store_a = DebugHelper.create_store(household, store_a_name)
store_b = DebugHelper.create_store(household, store_b_name)

IO.puts "Creating/Getting Inventory Sheet..."
sheet = DebugHelper.create_sheet(household, user, sheet_name)

IO.puts "Ensuring Initial Inventory Item in Sheet: #{item_name}, Brand: #{brand_name}, Store: #{store_a_name}, Qty: 5"
inv_item = DebugHelper.create_inventory_item(sheet, item_name, brand_name, store_a_name, 5)

IO.puts "Creating Trip and Stop at Store B"
{:ok, trip} = Receipts.create_trip(%{household_id: household.id, user_id: user.id, trip_start: DateTime.utc_now()})
{:ok, stop} = Receipts.create_stop(%{trip_id: trip.id, store_id: store_b.id, position: 1})

IO.puts "Simulating Purchase of #{item_name} (Brand: #{brand_name}) at Store B"
purchase_attrs = %{
  "brand" => brand_name,
  "item" => item_name,
  "total_price" => "10.00",
  "units" => "2",
  "price_per_unit" => "5.00",
  "count" => "1",
  "price_per_count" => "10.00",
  "household_id" => household.id,
  "user_id" => user.id,
  "stop_id" => stop.id,
  "date" => Date.utc_today()
}

{:ok, purchase} = Receipts.create_purchase(purchase_attrs)
IO.puts "Purchase Created: #{purchase.id}"

# Refetch Original Inventory Item
inv_item_updated = Repo.get(Inventory.Item, inv_item.id)
IO.puts "Original Inventory Item (Store: #{inv_item_updated.store}) Quantity: #{inv_item_updated.quantity}"

# Check for New Item in Purchases Sheet or elsewhere
new_items = Repo.all(from i in Inventory.Item, where: i.name == ^item_name and i.id != ^inv_item.id)

if inv_item_updated.quantity > 5 do
  IO.puts "RESULT: Original Inventory Item updated! (Existing behavior - Store ignored)"
else
  IO.puts "RESULT: Original Inventory Item NOT updated. (Desired behavior if we want split)"
end

if length(new_items) > 0 do
  IO.puts "New Item(s) Created:"
  Enum.each(new_items, fn i -> 
    sheet = Repo.get(Inventory.Sheet, i.sheet_id)
    IO.puts " - ID: #{i.id}, Sheet: #{sheet.name}, Store: #{i.store}, Qty: #{i.quantity}" 
  end)
else
  IO.puts "No new items created."
end
