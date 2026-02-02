alias MegaPlanner.Repo
import Ecto.Query

IO.puts("Starting cleanup...")

# Delete in proper order to avoid FK constraints
Repo.delete_all(MegaPlanner.Inventory.Item)
IO.puts("- Deleted inventory items")

Repo.delete_all(MegaPlanner.Inventory.ShoppingListItem)
IO.puts("- Deleted shopping list items")

Repo.delete_all(MegaPlanner.Inventory.ShoppingList)
IO.puts("- Deleted shopping lists")

Repo.delete_all(MegaPlanner.Inventory.Sheet)
IO.puts("- Deleted sheets")

Repo.delete_all(MegaPlanner.Receipts.Purchase)
IO.puts("- Deleted purchases")

Repo.delete_all(MegaPlanner.Receipts.Stop)
IO.puts("- Deleted stops")

Repo.delete_all(MegaPlanner.Receipts.Trip)
IO.puts("- Deleted trips")

Repo.delete_all(MegaPlanner.Receipts.Brand)
IO.puts("- Deleted brands")

Repo.delete_all(MegaPlanner.Receipts.Store)
IO.puts("- Deleted stores")

Repo.delete_all(MegaPlanner.Receipts.Unit)
IO.puts("- Deleted units")

Repo.delete_all(MegaPlanner.Receipts.Driver)
IO.puts("- Deleted drivers")

Repo.delete_all(MegaPlanner.Tags.Tag)
IO.puts("- Deleted tags")

Repo.delete_all(MegaPlanner.Budget.Entry)
IO.puts("- Deleted budget entries")

Repo.delete_all(MegaPlanner.Budget.Source)
IO.puts("- Deleted budget sources")

# Templates and autocomplete data
Repo.delete_all(MegaPlanner.Templates.TextTemplate)
IO.puts("- Deleted text templates (autocomplete suggestions)")

# Tasks and task steps
Repo.delete_all(MegaPlanner.Calendar.TaskStep)
IO.puts("- Deleted task steps")

Repo.delete_all(MegaPlanner.Calendar.Task)
IO.puts("- Deleted tasks")

IO.puts("\n✓ Cleanup complete!")

