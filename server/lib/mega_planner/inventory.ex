defmodule MegaPlanner.Inventory do
  @moduledoc """
  The Inventory context handles inventory sheets, items, and shopping lists.
  """

  import Ecto.Query, warn: false
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
  Deletes an item.
  """
  def delete_item(%Item{} = item) do
    Repo.delete(item)
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
    Repo.delete(list)
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
        where: s.household_id == ^household_id and i.is_necessity == true and i.quantity < i.min_quantity,
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
        new_quantity = item.quantity + shopping_item.quantity_needed

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
end
