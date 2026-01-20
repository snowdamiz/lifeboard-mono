
# inspect_duplicates.exs
alias MegaPlanner.Repo
alias MegaPlanner.Inventory.Item
import Ecto.Query

id = "230850cd-fe72-432a-8ddc-2f5916ac8a96"

item = Repo.get(Item, id) |> Repo.preload(:sheet)
if item do
  IO.puts "--- The Item Being Updated ---"
  IO.puts "ID: #{item.id}"
  IO.puts "Name: '#{item.name}'"
  IO.puts "Brand: '#{item.brand}'"
  IO.puts "Store: '#{item.store}'"
  IO.puts "Quantity: #{item.quantity}"
  IO.puts "Sheet: '#{item.sheet.name}'"
  IO.puts "Sheet ID: #{item.sheet_id}"
else
  IO.puts "Item #{id} not found?"
end

IO.puts "\n--- ALL Items matching Name='1' and Brand='1' ---"
# Assuming we can find the household from the item, or search globally (test env)
household_id = if item, do: item.sheet.household_id, else: nil

query = 
  if household_id do
    from i in Item, 
      join: s in assoc(i, :sheet),
      where: i.name == "1" and i.brand == "1" and s.household_id == ^household_id,
      preload: [:sheet]
  else
    from i in Item, where: i.name == "1" and i.brand == "1", preload: [:sheet]
  end

all_items = Repo.all(query)
Enum.each(all_items, fn i ->
  IO.puts "ID: #{i.id}"
  IO.puts "  Sheet: '#{i.sheet.name}'"
  IO.puts "  Store: '#{i.store}'"
  IO.puts "  Qty: #{i.quantity}"
end)
