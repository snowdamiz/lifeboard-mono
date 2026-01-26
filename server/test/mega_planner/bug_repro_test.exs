defmodule MegaPlanner.BugReproTest do
  use MegaPlanner.DataCase

  alias MegaPlanner.Inventory
  alias MegaPlanner.Inventory.Sheet

  describe "inventory transfers" do
    test "successfully transfers item and deletes source when empty" do
      user = MegaPlanner.AccountsFixtures.user_fixture()
      household_id = user.household_id

      # Setup Source Sheet
      {:ok, source_sheet} = Inventory.create_sheet(%{"name" => "Purchases", "household_id" => household_id, "user_id" => user.id})
      
      # Setup Target Sheet
      {:ok, target_sheet} = Inventory.create_sheet(%{"name" => "Pantry", "household_id" => household_id, "user_id" => user.id})

      # Create Item (Quantity 5)
      {:ok, item} = Inventory.create_item(%{
        "name" => "Test Item",
        "brand" => "TestBrand",
        "quantity" => 5,
        "sheet_id" => source_sheet.id,
        "min_quantity" => 1
      })

      # Create linked shopping list item
      {:ok, list} = Inventory.create_shopping_list(%{"name" => "Test List", "household_id" => household_id, "user_id" => user.id})
      {:ok, _sli} = Inventory.create_shopping_item(%{
        "shopping_list_id" => list.id,
        "inventory_item_id" => item.id,
        "quantity_needed" => 1,
        "household_id" => household_id,
        "user_id" => user.id
      })

      # 1. Partial Transfer (2)
      assert {:ok, :ok} = Inventory.transfer_item(item.id, target_sheet.id, 2)
      
      item = Inventory.get_item(item.id)
      assert item.quantity == 3

      # 2. Full Transfer (Remaining 3)
      assert {:ok, :ok} = Inventory.transfer_item(item.id, target_sheet.id, 3)

      # 3. Verify Source Deleted
      assert Inventory.get_item(item.id) == nil

      # 4. Verify Target Created/Updated
      target_items = Inventory.find_matching_items(household_id, "TestBrand", "Test Item")
      assert length(target_items) > 0
      target_item = List.first(target_items)
      assert target_item.quantity == 5
      assert target_item.sheet_id == target_sheet.id
    end
  end
end
