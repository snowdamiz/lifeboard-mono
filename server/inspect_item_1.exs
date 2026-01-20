
# inspect_item_1.exs
alias MegaPlanner.Repo
alias MegaPlanner.Inventory.Item
alias MegaPlanner.Receipts.Purchase
alias MegaPlanner.Receipts.Store
import Ecto.Query

# Find the item "1" / "1"
items = Repo.all(from i in Item, 
  where: i.name == "1" and i.brand == "1",
  preload: [:sheet]
)

IO.puts "\n--- Inventory Items (Name='1', Brand='1') ---"
Enum.each(items, fn i -> 
  IO.puts "ID: #{i.id}"
  IO.puts "  Sheet: #{i.sheet.name}"
  IO.puts "  Quantity: #{i.quantity}"
  IO.puts "  Store: #{inspect(i.store)}"
  IO.puts "  Unit: #{inspect(i.unit_of_measure)}"
  IO.puts "  Updated At: #{i.updated_at}"
end)

# Find recent purchases of "1" / "1"
IO.puts "\n--- Recent Purchases (Item='1', Brand='1') ---"
purchases = Repo.all(from p in Purchase,
  where: p.item == "1" and p.brand == "1",
  order_by: [desc: p.inserted_at],
  limit: 5,
  preload: [stop: :store]
)

Enum.each(purchases, fn p ->
  IO.puts "ID: #{p.id}"
  IO.puts "  Date/Time: #{p.inserted_at}"
  IO.puts "  Units: #{p.units}"
  IO.puts "  Count: #{p.count}"
  store_name = if p.stop && p.stop.store, do: p.stop.store.name, else: "N/A"
  IO.puts "  Store: #{store_name}"
end)
