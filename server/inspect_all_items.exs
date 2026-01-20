
# inspect_all_items.exs
alias MegaPlanner.Repo
alias MegaPlanner.Inventory.Item
alias MegaPlanner.Receipts.Purchase
import Ecto.Query

IO.puts "\n--- All Inventory Items (First 20) ---"
items = Repo.all(from i in Item, limit: 20, select: [:id, :name, :brand, :quantity, :store])
Enum.each(items, fn i -> 
  IO.puts "ID: #{i.id} | Name: '#{i.name}' | Brand: '#{i.brand}' | Qty: #{i.quantity} | Store: '#{i.store}'"
end)

IO.puts "\n--- All Purchases (First 20) ---"
purchases = Repo.all(from p in Purchase, limit: 20, order_by: [desc: p.inserted_at], select: [:id, :item, :brand, :units, :inserted_at])
Enum.each(purchases, fn p ->
  IO.puts "ID: #{p.id} | Item: '#{p.item}' | Brand: '#{p.brand}' | Units: #{p.units} | Date: #{p.inserted_at}"
end)
