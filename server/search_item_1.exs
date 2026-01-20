
# search_item_1.exs
alias MegaPlanner.Repo
alias MegaPlanner.Inventory.Item
alias MegaPlanner.Receipts.Purchase
import Ecto.Query

IO.puts "Searching for items/purchases with '1' in name/brand..."

items = Repo.all(from i in Item, where: ilike(i.name, "%1%") or ilike(i.brand, "%1%"))
IO.puts "Items found: #{length(items)}"
Enum.each(items, fn i -> IO.puts "Item: #{i.name} (#{i.brand})" end)

purchases = Repo.all(from p in Purchase, where: ilike(p.item, "%1%") or ilike(p.brand, "%1%"))
IO.puts "Purchases found: #{length(purchases)}"
Enum.each(purchases, fn p -> IO.puts "Purchase: #{p.item} (#{p.brand})" end)
