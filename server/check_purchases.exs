# Run this script with: mix run check_purchases.exs

# Connect to repo
{:ok, _} = Application.ensure_all_started(:mega_planner)

# Get your household_id
household = MegaPlanner.Accounts.list_households() |> List.first()
IO.puts("Checking household: #{household.name} (#{household.id})")

# Check recent purchases
purchases = MegaPlanner.Receipts.list_purchases(household.id) |> Enum.take(5)
IO.puts("\n=== Recent Purchases (#{length(purchases)}) ===")
Enum.each(purchases, fn p ->
  IO.puts("  - #{p.brand} #{p.item} | stop_id: #{inspect(p.stop_id)} | ID: #{p.id}")
end)

# Check Purchases sheet
case MegaPlanner.Repo.get_by(MegaPlanner.Inventory.Sheet, household_id: household.id, name: "Purchases") do
  nil ->
    IO.puts("\n=== Purchases Sheet: DOES NOT EXIST ===")
  
  sheet ->
    IO.puts("\n=== Purchases Sheet (ID: #{sheet.id}) ===")
    
    # Get ALL items in Purchases sheet
    items = MegaPlanner.Repo.all(
      from i in MegaPlanner.Inventory.Item,
      where: i.sheet_id == ^sheet.id,
      order_by: [desc: i.inserted_at]
    )
    
    IO.puts("Total items in Purchases sheet: #{length(items)}")
    IO.puts("\nItems:")
    Enum.each(items, fn item ->
      IO.puts("  - #{item.brand} #{item.name} | purchase_id: #{inspect(item.purchase_id)} | stop_id: #{inspect(item.stop_id)}")
    end)
end

IO.puts("\n=== Analysis ===")
IO.puts("If purchase count > item count, inventory items are NOT being created!")
