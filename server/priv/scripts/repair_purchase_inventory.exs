#!/usr/bin/env elixir
# Data Repair Script: Re-create inventory items from existing purchases
# Run with: mix run --no-start priv/scripts/repair_purchase_inventory.exs
# OR: elixir --sname repair -S mix run --no-start priv/scripts/repair_purchase_inventory.exs

# Start only the necessary applications without the web server
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto_sql)

# Start the repo directly
{:ok, _} = MegaPlanner.Repo.start_link()

alias MegaPlanner.{Repo, Inventory}
alias MegaPlanner.Inventory.{Sheet, Item}
alias MegaPlanner.Receipts.Purchase
import Ecto.Query

IO.puts("\n=== Purchase Inventory Repair Script ===\n")

# Get all purchases with stops
purchases = Repo.all(
  from p in Purchase,
    where: not is_nil(p.stop_id),
    preload: [:budget_entry, stop: :store]
)

IO.puts("Found #{length(purchases)} purchases with stop_id")

if length(purchases) == 0 do
  IO.puts("No purchases to process. Exiting.")
else
  # Group by household to process
  households = purchases |> Enum.group_by(& &1.household_id)

  Enum.each(households, fn {household_id, household_purchases} ->
    IO.puts("\n--- Processing household #{household_id} ---")
    
    # Get or create Purchases sheet
    sheet = case Repo.get_by(Sheet, household_id: household_id, name: "Purchases") do
      nil -> 
        user_id = case List.first(household_purchases) do
          %{budget_entry: %{user_id: uid}} when not is_nil(uid) -> uid
          _ -> nil
        end
        {:ok, s} = Inventory.create_sheet(%{
          "household_id" => household_id, 
          "name" => "Purchases", 
          "user_id" => user_id
        })
        IO.puts("  Created Purchases sheet")
        s
      s -> 
        IO.puts("  Found existing Purchases sheet")
        s
    end
    
    # Check each purchase for corresponding inventory item
    {created, skipped} = Enum.reduce(household_purchases, {0, 0}, fn purchase, {c, s} ->
      # Check if item already exists for this purchase
      existing = Repo.one(
        from i in Item,
          where: i.sheet_id == ^sheet.id and i.stop_id == ^purchase.stop_id,
          where: ilike(i.brand, ^(purchase.brand || "")) and ilike(i.name, ^(purchase.item || "")),
          limit: 1
      )
      
      if existing do
        {c, s + 1}
      else
        # Create the inventory item
        store_name = case purchase.stop do
          %{store: %{name: name}} when not is_nil(name) -> name
          _ -> nil
        end
        trip_id = case purchase.stop do
          %{trip_id: tid} -> tid
          _ -> nil
        end
        
        quantity = case purchase.units do
          nil -> 1
          units -> 
            if Decimal.gt?(units, 0), do: Decimal.to_integer(units), else: 1
        end
        
        attrs = %{
          "name" => purchase.item,
          "brand" => purchase.brand,
          "store" => store_name,
          "store_code" => purchase.store_code,
          "quantity" => quantity,
          "unit_of_measure" => purchase.unit_measurement,
          "price_per_unit" => purchase.price_per_unit,
          "total_price" => purchase.total_price,
          "purchase_id" => purchase.id,
          "trip_id" => trip_id,
          "stop_id" => purchase.stop_id,
          "purchase_date" => purchase.inserted_at,
          "sheet_id" => sheet.id,
          "count" => purchase.count,
          "item_name" => purchase.item_name,
          "taxable" => purchase.taxable
        }
        
        case Inventory.create_item(attrs) do
          {:ok, _item} ->
            IO.puts("  CREATED: #{purchase.brand || "(no brand)"} - #{purchase.item}")
            {c + 1, s}
          {:error, changeset} ->
            IO.puts("  ERROR: Failed to create item for #{purchase.brand} - #{purchase.item}: #{inspect(changeset.errors)}")
            {c, s}
        end
      end
    end)
    
    IO.puts("  Summary: Created #{created}, Skipped #{skipped}")
  end)
end

IO.puts("\n=== Repair Complete ===\n")
