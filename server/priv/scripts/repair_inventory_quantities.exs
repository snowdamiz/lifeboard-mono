defmodule MegaPlanner.Repo.DataMigrations.RepairInventoryQuantities do
  @moduledoc """
  Repairs inventory item quantities that were truncated to integers.
  Updates quantities from their linked purchases' units field (which preserved the decimal).
  """
  
  import Ecto.Query
  alias MegaPlanner.Repo
  alias MegaPlanner.Inventory.Item
  alias MegaPlanner.Receipts.Purchase
  
  def run do
    require Logger
    Logger.info("Starting inventory quantity repair...")
    
    # Get all inventory items that have a linked purchase
    items_with_purchases = from(i in Item,
      where: not is_nil(i.purchase_id),
      preload: [:purchase]
    ) |> Repo.all()
    
    repaired_count = Enum.reduce(items_with_purchases, 0, fn item, count ->
      purchase = item.purchase
      
      if purchase && purchase.units do
        # Check if item quantity differs from purchase units (was truncated)
        item_qty = item.quantity || Decimal.new(0)
        purchase_units = purchase.units
        
        # Compare - if they're different, repair and log
        if Decimal.compare(item_qty, purchase_units) != :eq do
          Logger.info("Repairing item '#{item.name}': #{item_qty} -> #{purchase_units}")
          
          case Repo.update(Item.changeset(item, %{quantity: purchase_units})) do
            {:ok, _} -> count + 1
            {:error, reason} ->
              Logger.error("Failed to repair item #{item.id}: #{inspect(reason)}")
              count
          end
        else
          count
        end
      else
        count
      end
    end)
    
    Logger.info("Repaired #{repaired_count} inventory items")
    {:ok, repaired_count}
  end
end

# Start required applications and repo
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto_sql)
{:ok, _} = MegaPlanner.Repo.start_link()

# Run the migration
MegaPlanner.Repo.DataMigrations.RepairInventoryQuantities.run()
