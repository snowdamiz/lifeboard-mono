
# 0. Start Repo
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto_sql)
{:ok, _} = MegaPlanner.Repo.start_link()
IO.puts("Repo started.")

alias MegaPlanner.{Repo, Inventory}
alias MegaPlanner.Inventory.{Sheet, Item}
import Ecto.Query

# 1. Setup Data
IO.puts("\n=== Setup ===")

# Get User
user = Repo.one(from u in MegaPlanner.Accounts.User, limit: 1)
IO.puts("User: #{user.email}")

# Get Sheets
purchases_sheet = Repo.get_by(Sheet, household_id: user.household_id, name: "Purchases")
pantry_sheet =    Repo.get_by(Sheet, household_id: user.household_id, name: "Pantry")

if purchases_sheet && pantry_sheet do
  IO.puts("Found Sheets: Purchases (#{purchases_sheet.id}), Pantry (#{pantry_sheet.id})")
else
  IO.puts("ERROR: Missing sheets. Purchases: #{inspect(purchases_sheet)}, Pantry: #{inspect(pantry_sheet)}")
  System.halt(1)
end

# Create Source Item in Purchases
item_name = "TransferDebugItem_#{System.unique_integer()}"
{:ok, source_item} = Inventory.create_item(%{
  name: item_name,
  brand: "Debug",
  quantity: 1,
  sheet_id: purchases_sheet.id,
  user_id: user.id
})
IO.puts("Created Source Item: ID=#{source_item.id}, Qty=#{source_item.quantity}")

# 2. Perform Transfer
transfer_qty = 1
IO.puts("\n=== Transferring #{transfer_qty} to Pantry ===")

case Inventory.transfer_item(source_item.id, pantry_sheet.id, transfer_qty) do
  :ok -> IO.puts("Transfer returned :ok")
  {:ok, _} -> IO.puts("Transfer returned {:ok, ...}")
  error -> 
    IO.puts("Transfer FAILED: #{inspect(error)}")
    System.halt(1)
end

# 3. Verify Result
IO.puts("\n=== Verification ===")

# Check Source Item (Should be deleted)
check_source = Repo.get(Item, source_item.id)
if check_source do
  IO.puts("FAIL: Source item STILL EXISTS with Qty=#{check_source.quantity}")
else
  IO.puts("PASS: Source item was DELETED")
end

# Check Target Item (Should exist with +1)
target_item = Repo.one(from i in Item, where: i.sheet_id == ^pantry_sheet.id and i.name == ^item_name)
if target_item do
  IO.puts("PASS: Target item created with Qty=#{target_item.quantity}")
else
  IO.puts("FAIL: Target item NOT FOUND")
end
