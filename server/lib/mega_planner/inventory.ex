defmodule MegaPlanner.Inventory do
  @moduledoc """
  The Inventory context handles inventory sheets, items, and shopping lists.
  """

  import Ecto.Query, warn: false
  require Logger
  alias MegaPlanner.Repo
  alias MegaPlanner.Inventory.{Sheet, Item, ShoppingList, ShoppingListItem}
  alias MegaPlanner.Tags.Tag

  # Sheets

  @doc """
  Returns the list of inventory sheets for a household.
  """
  def list_sheets(household_id, tag_ids \\ nil) do
    query = from(s in Sheet, where: s.household_id == ^household_id, order_by: [asc: s.name])

    query = if tag_ids && length(tag_ids) > 0 do
      from s in query,
        join: t in assoc(s, :tags),
        where: t.id in ^tag_ids,
        distinct: true
    else
      query
    end

    query
    |> Repo.all()
    |> Repo.preload(:tags)
  end

  @doc """
  Gets a single sheet with items and tags.
  """
  def get_sheet(id) do
    case Repo.get(Sheet, id) do
      nil -> nil
      sheet -> Repo.preload(sheet, [:tags, items: :tags])
    end
  end

  @doc """
  Gets a sheet for a specific household.
  """
  def get_household_sheet(household_id, id) do
    case Repo.get_by(Sheet, id: id, household_id: household_id) do
      nil -> nil
      sheet -> Repo.preload(sheet, [:tags, items: :tags])
    end
  end

  @doc """
  Creates a sheet with optional tags.
  """
  def create_sheet(attrs \\ %{}) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids", [])

    result =
      %Sheet{}
      |> Sheet.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, sheet} ->
        sheet = update_sheet_tags(sheet, tag_ids)
        {:ok, Repo.preload(sheet, :tags, force: true)}
      error ->
        error
    end
  end

  @doc """
  Updates a sheet with optional tags.
  """
  def update_sheet(%Sheet{} = sheet, attrs) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids")

    result =
      sheet
      |> Sheet.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, sheet} ->
        sheet = if tag_ids != nil, do: update_sheet_tags(sheet, tag_ids), else: sheet
        {:ok, Repo.preload(sheet, :tags, force: true)}
      error ->
        error
    end
  end

  defp update_sheet_tags(sheet, tag_ids) when is_list(tag_ids) do
    tags = from(t in Tag, where: t.id in ^tag_ids) |> Repo.all()
    sheet
    |> Repo.preload(:tags)
    |> Sheet.tags_changeset(tags)
    |> Repo.update!()
  end

  defp update_sheet_tags(sheet, _), do: sheet

  @doc """
  Deletes a sheet.
  """
  def delete_sheet(%Sheet{} = sheet) do
    Repo.delete(sheet)
  end

  # Items

  @doc """
  Gets a single item.
  """
  def get_item(id) do
    case Repo.get(Item, id) do
      nil -> nil
      item -> Repo.preload(item, :tags)
    end
  end

  @doc """
  Creates an item with optional tags.
  """
  def create_item(attrs \\ %{}) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids", [])

    result =
      %Item{}
      |> Item.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, item} ->
        item = update_item_tags(item, tag_ids)
        {:ok, Repo.preload(item, :tags, force: true)}
      error ->
        error
    end
  end

  @doc """
  Updates an item with optional tags.
  """
  def update_item(%Item{} = item, attrs) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids")

    result =
      item
      |> Item.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, item} ->
        item = if tag_ids != nil, do: update_item_tags(item, tag_ids), else: item

        # Sync usage_mode globally to all inventory items and purchases with same brand+item
        if Map.has_key?(attrs, "usage_mode") && item.brand && item.name do
          new_mode = attrs["usage_mode"]
          item_with_sheet = Repo.preload(item, :sheet)
          household_id = item_with_sheet.sheet.household_id

          # Update all other inventory items with same brand+name in the household
          from(i in Item,
            join: s in MegaPlanner.Inventory.Sheet, on: i.sheet_id == s.id,
            where: s.household_id == ^household_id,
            where: i.id != ^item.id,
            where: fragment("LOWER(?) = LOWER(?)", i.brand, ^item.brand),
            where: fragment("LOWER(?) = LOWER(?)", i.name, ^item.name)
          )
          |> Repo.update_all(set: [usage_mode: new_mode])

          # Update all purchases with same brand+item in the household
          from(p in MegaPlanner.Receipts.Purchase,
            where: p.household_id == ^household_id,
            where: fragment("LOWER(?) = LOWER(?)", p.brand, ^item.brand),
            where: fragment("LOWER(?) = LOWER(?)", p.item, ^item.name)
          )
          |> Repo.update_all(set: [usage_mode: new_mode])
        end

        {:ok, Repo.preload(item, :tags, force: true)}
      error ->
        error
    end
  end

  defp update_item_tags(item, tag_ids) when is_list(tag_ids) do
    tags = from(t in Tag, where: t.id in ^tag_ids) |> Repo.all()
    item
    |> Repo.preload(:tags)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, tags)
    |> Repo.update!()
  end

  defp update_item_tags(item, _), do: item

  @doc """
  Deletes an item. If `cascade_purchase: true` is passed and the item is linked
  to a purchase, also deletes the purchase (which cascade-deletes the associated
  budget entry). Defaults to `false` to preserve purchase/budget records during
  transfers.
  """
  def delete_item(%Item{} = item, opts \\ []) do
    cascade = Keyword.get(opts, :cascade_purchase, false)

    if cascade && item.purchase_id do
      Repo.transaction(fn ->
        case Repo.get(MegaPlanner.Receipts.Purchase, item.purchase_id) do
          nil -> :ok
          purchase ->
            # Unlink this item from the purchase first (avoid FK violation)
            item
            |> Ecto.Changeset.change(purchase_id: nil)
            |> Repo.update!()

            # Delete the purchase (cascades to budget entry via DB FK)
            MegaPlanner.Receipts.delete_purchase(purchase)
        end

        # Re-fetch the item in case it was modified above
        case Repo.get(Item, item.id) do
          nil -> :ok  # Already cleaned up
          fresh_item -> Repo.delete!(fresh_item)
        end
      end)
      |> case do
        {:ok, _} -> {:ok, item}
        {:error, reason} -> {:error, reason}
      end
    else
      Repo.delete(item)
    end
  end

  # Shopping Lists

  @doc """
  Returns all shopping lists for a household, optionally filtered by tags.
  """
  def list_shopping_lists(household_id, tag_ids \\ nil) do
    query = from(l in ShoppingList,
      where: l.household_id == ^household_id,
      order_by: [desc: l.is_auto_generated, asc: l.name]
    )

    query = if tag_ids && length(tag_ids) > 0 do
      from l in query,
        join: t in assoc(l, :tags),
        where: t.id in ^tag_ids,
        distinct: true
    else
      query
    end

    query
    |> Repo.all()
    |> Repo.preload([:tags, items: [inventory_item: :sheet]])
  end

  @doc """
  Gets a shopping list with items and tags.
  """
  def get_shopping_list(id) do
    case Repo.get(ShoppingList, id) do
      nil -> nil
      list -> Repo.preload(list, [:tags, items: [inventory_item: :sheet]])
    end
  end

  @doc """
  Gets a shopping list for a specific household.
  """
  def get_household_shopping_list(household_id, id) do
    case Repo.get_by(ShoppingList, id: id, household_id: household_id) do
      nil -> nil
      list -> Repo.preload(list, [:tags, items: [inventory_item: :sheet]])
    end
  end

  @doc """
  Gets or creates the auto-generated shopping list for a household.
  """
  def get_or_create_auto_list(household_id, user_id) do
    case Repo.get_by(ShoppingList, household_id: household_id, is_auto_generated: true) do
      nil ->
        {:ok, list} = create_shopping_list(%{
          name: "Auto-Generated",
          is_auto_generated: true,
          household_id: household_id,
          user_id: user_id
        })
        list
      list ->
        Repo.preload(list, [:tags, items: [inventory_item: :sheet]])
    end
  end

  @doc """
  Creates a shopping list.
  """
  def create_shopping_list(attrs \\ %{}) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids", [])

    %ShoppingList{}
    |> ShoppingList.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, list} ->
        list = update_list_tags(list, tag_ids)
        {:ok, Repo.preload(list, [:tags, items: [inventory_item: :sheet]])}
      error -> error
    end
  end

  @doc """
  Updates a shopping list.
  """
  def update_shopping_list(%ShoppingList{} = list, attrs) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids")

    list
    |> ShoppingList.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, list} ->
        list = if tag_ids != nil, do: update_list_tags(list, tag_ids), else: list
        {:ok, Repo.preload(list, [:tags, items: [inventory_item: :sheet]], force: true)}
      error -> error
    end
  end

  defp update_list_tags(list, tag_ids) when is_list(tag_ids) do
    tags = from(t in Tag, where: t.id in ^tag_ids) |> Repo.all()
    list
    |> Repo.preload(:tags)
    |> ShoppingList.tags_changeset(tags)
    |> Repo.update!()
  end

  defp update_list_tags(list, _), do: list

  @doc """
  Deletes a shopping list.
  """
  def delete_shopping_list(%ShoppingList{} = list) do
    # Try simple delete first, but catch any unexpected crashes
    try do
      # Preload and clear tags first just in case
      list = Repo.preload(list, :tags)
      list
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:tags, [])
      |> Repo.update!()

      Repo.delete(list)
    rescue
      e ->
        require Logger
        Logger.error("Failed to delete shopping list: #{inspect(e)}")
        {:error, "Delete failed: #{inspect(e)}"}
    end
  end

  # Shopping List Items

  @doc """
  Returns shopping items for a specific list.
  """
  def list_shopping_items(shopping_list_id) do
    from(s in ShoppingListItem,
      where: s.shopping_list_id == ^shopping_list_id and s.purchased == false,
      preload: [inventory_item: :sheet],
      order_by: [asc: s.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns all unpurchased shopping items for a household (across all lists).
  """
  def list_all_shopping_items(household_id) do
    from(s in ShoppingListItem,
      where: s.household_id == ^household_id and s.purchased == false,
      preload: [:shopping_list, inventory_item: :sheet],
      order_by: [asc: s.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a shopping list item.
  """
  def get_shopping_item(id) do
    Repo.get(ShoppingListItem, id)
    |> Repo.preload([:shopping_list, inventory_item: :sheet])
  end

  @doc """
  Creates a shopping list item.
  """
  def create_shopping_item(attrs \\ %{}) do
    %ShoppingListItem{}
    |> ShoppingListItem.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, item} -> {:ok, Repo.preload(item, [:shopping_list, inventory_item: :sheet])}
      error -> error
    end
  end

  @doc """
  Updates a shopping list item.
  """
  def update_shopping_item(%ShoppingListItem{} = item, attrs) do
    item
    |> ShoppingListItem.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, item} -> {:ok, Repo.preload(item, [:shopping_list, inventory_item: :sheet], force: true)}
      error -> error
    end
  end

  @doc """
  Deletes a shopping list item.
  """
  def delete_shopping_item(%ShoppingListItem{} = item) do
    Repo.delete(item)
  end

  @doc """
  Generates a shopping list from items below minimum quantity.
  """
  def generate_shopping_list(user_id, household_id) do
    # Get or create the auto-generated list
    auto_list = get_or_create_auto_list(household_id, user_id)

    # Get all items below minimum quantity that are necessities
    items_needing_replenishment =
      from(i in Item,
        join: s in Sheet, on: i.sheet_id == s.id,
        where: s.household_id == ^household_id and i.quantity < i.min_quantity,
        select: %{id: i.id, quantity: i.quantity, min_quantity: i.min_quantity}
      )
      |> Repo.all()

    # Create or update shopping list items
    Enum.each(items_needing_replenishment, fn item ->
      quantity_needed = item.min_quantity - item.quantity

      # Check if an unpurchased item already exists in the auto-generated list
      existing =
        from(s in ShoppingListItem,
          where: s.shopping_list_id == ^auto_list.id and
                 s.inventory_item_id == ^item.id and
                 s.purchased == false
        )
        |> Repo.one()

      case existing do
        nil ->
          # Create new shopping list item
          %ShoppingListItem{}
          |> ShoppingListItem.changeset(%{
            shopping_list_id: auto_list.id,
            inventory_item_id: item.id,
            user_id: user_id,
            household_id: household_id,
            quantity_needed: quantity_needed,
            purchased: false
          })
          |> Repo.insert()

        shopping_item ->
          # Update existing item's quantity
          shopping_item
          |> ShoppingListItem.changeset(%{quantity_needed: quantity_needed})
          |> Repo.update()
      end
    end)

    get_shopping_list(auto_list.id)
  end

  @doc """
  Marks a shopping item as purchased and updates inventory if applicable.
  """
  def mark_purchased(%ShoppingListItem{} = shopping_item) do
    Repo.transaction(fn ->
      # Update inventory quantity if linked to an inventory item
      if shopping_item.inventory_item_id do
        item = get_item(shopping_item.inventory_item_id)
        new_quantity = Decimal.add(item.quantity, shopping_item.quantity_needed)

        case update_item(item, %{quantity: new_quantity}) do
          {:ok, _} -> :ok
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end

      # Mark as purchased
      case update_shopping_item(shopping_item, %{purchased: true}) do
        {:ok, updated} -> updated
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  alias MegaPlanner.Receipts.Purchase

  @doc """
  Creates an inventory item from a purchase.
  """
  def create_item_from_purchase(%Purchase{} = purchase) do
    IO.puts("[create_item_from_purchase] Starting for purchase ID: #{purchase.id}")
    purchase = Repo.preload(purchase, [:budget_entry, stop: :store])
    household_id = purchase.household_id
    
    # Determine quantity - this represents the per-container amount for count-mode items
    # For "By Count" items: quantity = amount per container (e.g., 8 tea bags per box)
    # If purchase has both count and units, compute per-container: units / count
    purchase_count = purchase.count || Decimal.new(0)
    purchase_units = purchase.units || Decimal.new(0)
    
    quantity_per_container = 
      cond do
        Decimal.gt?(purchase_units, Decimal.new(0)) && Decimal.gt?(purchase_count, Decimal.new(1)) ->
          # Multiple containers: compute per-container amount
          Decimal.div(purchase_units, purchase_count)
        Decimal.gt?(purchase_units, Decimal.new(0)) ->
          # Single container or no count: use units directly
          purchase_units
        true ->
          Decimal.new(1)
      end

    IO.puts("[create_item_from_purchase] Quantity per container: #{quantity_per_container}")

    # Normalize inputs for search
    search_brand = String.trim(purchase.brand || "")
    search_item = String.trim(purchase.item || "")

    # Determine purchase store name for matching (kept for potential future use)
    _store_name = if purchase.stop && purchase.stop.store, do: String.trim(purchase.stop.store.name), else: nil

    # 1. Identify/Create the staging sheet
    user_id = if purchase.budget_entry, do: purchase.budget_entry.user_id, else: nil
    
    case get_or_create_purchases_sheet(household_id, user_id) do
      {:ok, purchases_sheet} ->
        IO.puts("[create_item_from_purchase] Purchases sheet ID: #{purchases_sheet.id}")

        # 2. Try to find matching item in Purchases sheet FOR THIS SPECIFIC STOP
        # Priority: Store Code -> (Brand + Name + Stop)
        existing_item = 
          if purchase.store_code do
            Repo.one(from i in Item, 
              where: i.sheet_id == ^purchases_sheet.id and 
                     i.store_code == ^purchase.store_code and 
                     i.stop_id == ^purchase.stop_id)
          end

        # Fallback to Name + Brand + Stop if no store code match found
        existing_item = existing_item || Repo.one(
          from i in Item,
            where: i.sheet_id == ^purchases_sheet.id and 
                   ilike(i.brand, ^search_brand) and 
                   ilike(i.name, ^search_item) and
                   i.stop_id == ^purchase.stop_id,
            limit: 1
        )

        IO.puts("[create_item_from_purchase] Existing item: #{inspect(existing_item)}")

        result = case existing_item do
          nil ->
            IO.puts("[create_item_from_purchase] Creating new inventory item")
            # Create new item in Purchases sheet
            create_new_inventory_item(purchase, quantity_per_container)
          
          item ->
            IO.puts("[create_item_from_purchase] Updating existing inventory item")
            # Update existing item in Purchases sheet
            # In count mode, only add to count (not quantity)
            if item.usage_mode == "count" do
              count_to_add = purchase.count || Decimal.new(1)
              existing_count = item.count || Decimal.new(0)
              update_item(item, %{count: Decimal.add(existing_count, count_to_add)})
            else
              update_item(item, %{quantity: Decimal.add(item.quantity, quantity_per_container)})
            end
        end

        IO.puts("[create_item_from_purchase] Result: #{inspect(result)}")

        # Auto-complete matching shopping list items
        complete_shopping_list_items_for_purchase(purchase)

        result
      
      error ->
        IO.puts("[create_item_from_purchase] ✗ Failed to get/create purchases sheet: #{inspect(error)}")
        error
    end
  end

  defp create_new_inventory_item(purchase, quantity) do
    Logger.info("[create_new_inventory_item] Starting for purchase ID: #{purchase.id}, quantity: #{quantity}")
    # We need a user to assign the sheet to. 
    user_id = if purchase.budget_entry, do: purchase.budget_entry.user_id, else: nil

    case get_or_create_purchases_sheet(purchase.household_id, user_id) do
       {:ok, sheet} ->
          store_name = if purchase.stop && purchase.stop.store, do: purchase.stop.store.name, else: nil
          trip_id = if purchase.stop, do: purchase.stop.trip_id, else: nil
          stop_id = purchase.stop_id
          
          attrs = %{
            name: purchase.item,
            brand: purchase.brand,
            store: store_name,
            store_code: purchase.store_code,
            quantity: quantity,
            unit_of_measure: purchase.unit_measurement,
            price_per_unit: purchase.price_per_unit,
            price_per_count: purchase.price_per_count,
            total_price: purchase.total_price,
            purchase_id: purchase.id,
            trip_id: trip_id,
            stop_id: stop_id,
            purchase_date: purchase.inserted_at,
            sheet_id: sheet.id,
            count: purchase.count,
            count_unit: purchase.count_unit,
            item_name: purchase.item_name,
            taxable: purchase.taxable,
            usage_mode: purchase.usage_mode || "count",
          }
          
          Logger.info("[create_new_inventory_item] Creating item with attrs: #{inspect(attrs)}")
          result = create_item(attrs)
          Logger.info("[create_new_inventory_item] Create result: #{inspect(result)}")
          result
       error -> 
          Logger.error("[create_new_inventory_item] Failed to get purchases sheet: #{inspect(error)}")
          error
    end
  end

  defp get_or_create_purchases_sheet(household_id, user_id) do
    # Try to find common purchases sheet
    case Repo.get_by(Sheet, household_id: household_id, name: "Purchases") do
      nil -> 
        # Create one owned by the purchaser
        create_sheet(%{
          household_id: household_id, 
          name: "Purchases", 
          user_id: user_id
        })
      sheet -> {:ok, sheet}
    end
  end

  # Trip Receipts

  @doc """
  Lists inventory items from the Purchases sheet grouped by stop_id.
  Returns a list of trip receipts with their items.
  """
  def list_trip_receipts(household_id) do
    case Repo.get_by(Sheet, household_id: household_id, name: "Purchases") do
      nil -> []
      sheet ->
        from(i in Item,
          where: i.sheet_id == ^sheet.id and not is_nil(i.stop_id),
          preload: [:tags, stop: [:store, :trip]],
          order_by: [desc: i.purchase_date]
        )
        |> Repo.all()
        |> Enum.group_by(&(&1.stop_id))
        |> Enum.map(fn {_stop_id, items} ->
          first_item = List.first(items)
          stop = first_item.stop
          
          # Build the correct display datetime using trip date + stop's time_arrived
          # This preserves the local receipt time (e.g., 14:26) without timezone issues
          trip_start = compute_trip_display_time(stop)
          
          %{
            id: stop.id,
            trip_id: stop.trip && stop.trip.id,
            store_name: (stop.store && stop.store.name) || stop.stop_name,
            trip_start: trip_start,
            date: first_item.purchase_date,
            items: items
          }
        end)
        |> Enum.sort_by(& &1.date, {:desc, DateTime})
    end
  end
  
  # Compute the correct display time for a trip by combining trip date with stop's time_arrived
  # Returns an ISO-formatted string without timezone suffix so frontend interprets as local time
  defp compute_trip_display_time(stop) do
    cond do
      # Use stop's time_arrived with trip's date (preferred - this is the actual receipt time)
      stop.time_arrived && stop.trip && stop.trip.trip_start ->
        trip_date = DateTime.to_date(stop.trip.trip_start)
        # Format as ISO string WITHOUT timezone suffix (e.g., "2026-01-18T14:26:00")
        # Frontend will interpret this as local time
        date_str = Date.to_iso8601(trip_date)
        time_str = Time.to_iso8601(stop.time_arrived)
        "#{date_str}T#{time_str}"
        
      # Fall back to trip_start if no stop time
      stop.trip && stop.trip.trip_start ->
        DateTime.to_iso8601(stop.trip.trip_start)
        
      # No trip info available
      true ->
        nil
    end
  end

  @doc """
  Finds all inventory items matching brand+name across non-Purchases sheets.
  """
  def find_matching_items(household_id, brand, name) do
    search_brand = brand || ""
    search_name = name || ""
    
    from(i in Item,
      join: s in assoc(i, :sheet),
      where: s.household_id == ^household_id and 
             s.name != "Purchases" and
             ilike(i.brand, ^search_brand) and 
             ilike(i.name, ^search_name),
      preload: [:sheet, :tags]
    )
    |> Repo.all()
  end

  @doc """
  Transfers quantity from source item to target sheet.
  Creates new item in target if none exists, otherwise adds to existing.
  Transferred items become regular inventory (no purchase linkage).
  
  When the source item's usage_mode is "count" and it has a count field,
  the `amount` parameter represents a count of containers and the function
  transfers proportional quantity. Otherwise `amount` is raw quantity.
  """
  def transfer_item(source_item_id, target_sheet_id, amount, usage_mode \\ "count") do
    Repo.transaction(fn ->
      source = get_item(source_item_id)
      
      if source == nil do
        Repo.rollback(:item_not_found)
      end

      # Use the frontend-supplied usage_mode to determine transfer behavior
      # 'count' -> amount is # of containers, proportional qty moves with it
      # 'quantity' -> amount is raw quantity
      use_count_mode = usage_mode == "count" && source.count != nil && 
                       Decimal.compare(source.count || Decimal.new(0), Decimal.new(0)) == :gt

      # Determine the actual quantity to transfer and what to deduct based on mode
      {transfer_qty, should_delete} = if use_count_mode do
        source_count = source.count
        source_qty = source.quantity || Decimal.new(0)
        
        # Validate we have enough count
        if Decimal.lt?(source_count, amount) do
          Repo.rollback(:insufficient_quantity)
        end
        
        new_count = Decimal.sub(source_count, amount)
        
        # Calculate proportional quantity to transfer
        proportional_qty = if Decimal.compare(new_count, 0) != :gt do
          # Transferring all remaining count -> transfer all remaining quantity
          source_qty
        else
          # Proportional: (amount / source_count) * source_qty
          if Decimal.compare(source_count, 0) == :gt do
            Decimal.mult(Decimal.div(amount, source_count), source_qty)
          else
            source_qty
          end
        end
        
        Logger.info("Transfer (count mode): count #{source_count} -> #{new_count}, qty #{source_qty}, proportional_qty #{proportional_qty}")
        
        if Decimal.compare(new_count, 0) != :gt do
          {proportional_qty, true}
        else
          new_qty = Decimal.sub(source_qty, proportional_qty)
          {:ok, _} = update_item(source, %{count: new_count, quantity: new_qty})
          {proportional_qty, false}
        end
      else
        # Quantity-based transfer (original behavior)
        if Decimal.lt?(source.quantity, amount) do
          Repo.rollback(:insufficient_quantity)
        end
        
        new_quantity = Decimal.sub(source.quantity, amount)
        Logger.info("Transfer (qty mode): Source ID #{source.id}, Qty #{source.quantity}, Transfer #{amount}, New #{new_quantity}")
        
        if Decimal.compare(new_quantity, 0) != :gt do
          {amount, true}
        else
          {:ok, _} = update_item(source, %{quantity: new_quantity})
          {amount, false}
        end
      end
      
      # Look for existing matching item in target sheet
      target_item = Repo.one(
        from i in Item,
          where: i.sheet_id == ^target_sheet_id and
                 i.name == ^source.name and
                 coalesce(i.brand, "") == ^(source.brand || ""),
          limit: 1
      )
      
      # Update or create target
      case target_item do
        nil ->
          # Create new item in target (no purchase linkage)
          target_attrs = %{
            "name" => source.name,
            "brand" => source.brand,
            "store" => source.store,
            "quantity" => transfer_qty,
            "sheet_id" => target_sheet_id,
            "unit_of_measure" => source.unit_of_measure,
            "store_code" => source.store_code,
            "usage_mode" => source.usage_mode,
            "count_unit" => source.count_unit
          }
          
          # Set count on the target for both modes
          target_attrs = if use_count_mode do
            Map.put(target_attrs, "count", amount)
          else
            # Quantity mode: quantity is per-container, count tracks containers
            Map.put(target_attrs, "count", Decimal.new(1))
          end
          
          {:ok, _} = create_item(target_attrs)
        item ->
          # Add to existing item
          if use_count_mode do
            # Count mode: quantity is per-container (stays the same),
            # only increment count (number of containers)
            existing_count = item.count || Decimal.new(0)
            update_attrs = %{
              count: Decimal.add(existing_count, amount)
            }
            {:ok, _} = update_item(item, update_attrs)
          else
            # Quantity mode: quantity is per-container (stays the same),
            # only increment count (number of containers)
            existing_count = item.count || Decimal.new(0)
            update_attrs = %{count: Decimal.add(existing_count, Decimal.new(1))}
            {:ok, _} = update_item(item, update_attrs)
          end
      end
      
      # Delete source if fully consumed
      if should_delete do
        Logger.info("Transfer: Deleting source item #{source.id}")
        
        # Unlink from shopping lists before deletion to prevent FK violation
        shopping_item_ids = from(s in ShoppingListItem, 
          where: s.inventory_item_id == ^source.id, 
          select: s.id
        ) |> Repo.all()

        if length(shopping_item_ids) > 0 do
          from(s in ShoppingListItem,
            where: s.id in ^shopping_item_ids,
            update: [set: [inventory_item_id: nil, name: ^source.name]] 
          )
          |> Repo.update_all([])
        end

        delete_item(source)
      end
      
      :ok
    end)
  end

  # Shopping List Completion

  @doc """
  Matches a purchase against shopping list items by brand + item name.
  Sets `completed_at` on matched items and auto-completes lists where all items are matched.
  """
  def complete_shopping_list_items_for_purchase(%Purchase{} = purchase) do
    household_id = purchase.household_id
    purchase_item_name = String.downcase(String.trim(purchase.item || ""))
    purchase_brand = String.downcase(String.trim(purchase.brand || ""))

    if purchase_item_name == "" do
      :noop
    else
      # Build query based on whether purchase has a brand
      matching_items = if purchase_brand != "" do
        # Match on both item name AND brand
        from(sli in ShoppingListItem,
          left_join: inv in assoc(sli, :inventory_item),
          where: sli.household_id == ^household_id
             and sli.purchased == false
             and is_nil(sli.completed_at)
             and fragment("LOWER(TRIM(COALESCE(?, ?)))", sli.name, inv.name) == ^purchase_item_name
             and fragment("LOWER(TRIM(COALESCE(?, '')))", inv.brand) == ^purchase_brand
        ) |> Repo.all()
      else
        # Match on item name only (no brand filter)
        from(sli in ShoppingListItem,
          left_join: inv in assoc(sli, :inventory_item),
          where: sli.household_id == ^household_id
             and sli.purchased == false
             and is_nil(sli.completed_at)
             and fragment("LOWER(TRIM(COALESCE(?, ?)))", sli.name, inv.name) == ^purchase_item_name
        ) |> Repo.all()
      end

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      affected_list_ids = Enum.map(matching_items, fn item ->
        item
        |> ShoppingListItem.changeset(%{completed_at: now})
        |> Repo.update!()
        item.shopping_list_id
      end)
      |> Enum.uniq()

      # Check if any affected lists are now fully completed
      Enum.each(affected_list_ids, &maybe_complete_list/1)

      {:ok, length(matching_items)}
    end
  end

  defp maybe_complete_list(list_id) do
    # Count items not yet completed (no completed_at and not purchased)
    remaining = from(sli in ShoppingListItem,
      where: sli.shopping_list_id == ^list_id
         and sli.purchased == false
         and is_nil(sli.completed_at),
      select: count(sli.id)
    ) |> Repo.one()

    if remaining == 0 do
      list = Repo.get!(ShoppingList, list_id)
      list
      |> ShoppingList.changeset(%{status: "completed"})
      |> Repo.update!()
    end
  end
end
