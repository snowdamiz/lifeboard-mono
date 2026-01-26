# reproduce_issue.exs
alias MegaPlanner.Repo
alias MegaPlanner.Inventory
alias MegaPlanner.Receipts
alias MegaPlanner.Accounts

# Ensure we have a user and household
user = Repo.one(from u in MegaPlanner.Accounts.User, limit: 1) || raise "No user found"
household_id = user.current_household_id || raise "No household found"

# 1. Create specific sheets
# Ensure we have a "Pantry" sheet (non-Purchases)
{:ok, pantry_sheet} = case Repo.get_by(Inventory.Sheet, household_id: household_id, name: "Pantry") do
  nil -> Inventory.create_sheet(%{household_id: household_id, name: "Pantry", user_id: user.id})
  sheet -> {:ok, sheet}
end

# Ensure we have a "Purchases" sheet
{:ok, purchases_sheet} = Inventory.get_or_create_purchases_sheet(household_id, user.id)

# 2. Creating a unique store code for test
store_code = "TEST-CODE-#{System.system_time()}"

# 3. Create an item in Pantry with this store code
{:ok, pantry_item} = Inventory.create_item(%{
  "name" => "Existing Pantry Item",
  "store_code" => store_code,
  "quantity" => 5,
  "sheet_id" => pantry_sheet.id
})

IO.puts "Created item in Pantry with quantity: #{pantry_item.quantity}"

# 4. Create a purchase with the same store code
# We need a dummy budget entry and purchase
{:ok, entry} = MegaPlanner.Budget.create_entry(%{
  "household_id" => household_id,
  "user_id" => user.id,
  "date" => Date.utc_today(),
  "amount" => Decimal.new("10.00"),
  "type" => "expense",
  "notes" => "Test Purchase"
})

{:ok, purchase} = Receipts.Purchase.changeset(%Receipts.Purchase{}, %{
  "item" => "New Purchase Item",
  "store_code" => store_code,
  "total_price" => Decimal.new("10.00"),
  "quantity" => 1, # Does purchase have quantity? No, it has units/count/etc.
  "count" => 1,
  "household_id" => household_id,
  "budget_entry_id" => entry.id
}) |> Repo.insert()

# 5. Trigger item creation
# This calls create_item_from_purchase
{:ok, _result} = Inventory.create_item_from_purchase(purchase)

# 6. Check results
updated_pantry_item = Inventory.get_item(pantry_item.id)
purchases_items = Repo.all(from i in Inventory.Item, where: i.sheet_id == ^purchases_sheet.id and i.store_code == ^store_code)

IO.puts "Updated Pantry Item Quantity: #{updated_pantry_item.quantity}"
IO.puts "Items in Purchases Sheet with store code: #{length(purchases_items)}"

if updated_pantry_item.quantity > 5 do
  IO.puts "\nFAIL: Pantry item quantity increased! The purchase updated the existing item instead of staging."
else
  IO.puts "\nSUCCESS: Pantry item quantity unchanged."
end

if length(purchases_items) == 0 do
  IO.puts "FAIL: No item created in Purchases sheet."
else
  IO.puts "SUCCESS: Item created in Purchases sheet."
end
