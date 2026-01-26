defmodule MegaPlanner.BugReproTripMergeTest do
  use MegaPlanner.DataCase

  alias MegaPlanner.{Inventory, Receipts}
  alias MegaPlanner.Inventory.{Sheet, Item}
  alias MegaPlanner.Receipts.{Trip, Stop, Purchase}
  
  test "purchase of existing item should NOT merge into generic inventory automatically" do
    user = MegaPlanner.AccountsFixtures.user_fixture()
    household_id = user.household_id
    
    # 1. Start with "Pantry" and "Purchases" sheets
    {:ok, pantry} = Inventory.create_sheet(%{household_id: household_id, name: "Pantry", user_id: user.id})
    {:ok, purchases_sheet} = Inventory.create_sheet(%{household_id: household_id, name: "Purchases", user_id: user.id})
    
    # 2. Existing Item in Pantry
    {:ok, existing_item} = Inventory.create_item(%{
      name: "Milk",
      brand: "Moo",
      quantity: 1,
      sheet_id: pantry.id,
      store: "Test Store"
    })
    
    # 3. Create Trip Purchase
    {:ok, trip} = Receipts.create_trip(%{trip_start: DateTime.utc_now(), household_id: household_id})
    {:ok, stop} = Receipts.create_stop(%{trip_id: trip.id, position: 0, store_name: "Test Store"})
    
    {:ok, _purchase} = Receipts.create_purchase(%{
      "household_id" => household_id,
      "user_id" => user.id,
      "brand" => "Moo",
      "item" => "Milk",
      "count" => 1,
      "total_price" => 5.00,
      "date" => Date.utc_today(),
      "stop_id" => stop.id
    })
    
    # 4. Assertions
    
    # Check Pantry Item (Should remain 1 if fix works, or if we change logic)
    # Current BUG: It becomes 2
    updated_pantry = Inventory.get_item(existing_item.id)
    
    # Check Purchases Sheet (Should have 1 new item)
    # Current BUG: It has 0
    purchase_sheet_item = Repo.one(from i in Item, 
      where: i.sheet_id == ^purchases_sheet.id and i.name == "Milk"
    )
    
    IO.puts("\n\nDEBUG RESULTS:")
    IO.puts("Pantry Qty: #{updated_pantry.quantity}")
    if purchase_sheet_item do
      IO.puts("Purchases Sheet Item: FOUND")
    else
      IO.puts("Purchases Sheet Item: NOT FOUND") 
    end
    IO.puts("\n")

    # We expect the Bug to exist, so let's assert the BUGGY behavior first to confirm reproduction
    assert updated_pantry.quantity == 2, "Bug not reproduced: Pantry quantity should have increased"
    refute purchase_sheet_item, "Bug not reproduced: Purchase item should NOT exist in staging yet"
  end
end
