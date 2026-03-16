defmodule MegaPlanner.SQLiteRegressionsTest do
  use MegaPlanner.DataCase

  alias MegaPlanner.{Accounts, Inventory, Receipts, Repo}
  alias MegaPlanner.Accounts.UserPreferences

  @corrupted_inventory_widget "696e7665-6e74-6f72-795f-737461747573"

  describe "trip receipts" do
    test "returns store_name when a stop has no linked store" do
      user = MegaPlanner.AccountsFixtures.user_fixture()
      household_id = user.household_id

      {:ok, purchases_sheet} =
        Inventory.create_sheet(%{
          "name" => "Purchases",
          "household_id" => household_id,
          "user_id" => user.id
        })

      {:ok, trip} =
        Receipts.create_trip(%{
          household_id: household_id,
          user_id: user.id,
          trip_start: ~U[2026-03-16 23:10:00Z]
        })

      {:ok, stop} =
        Receipts.create_stop(%{
          trip_id: trip.id,
          position: 1,
          store_name: "Manual Store Name",
          time_arrived: ~T[14:26:00]
        })

      {:ok, _item} =
        Inventory.create_item(%{
          "name" => "Receipt Repro Item",
          "sheet_id" => purchases_sheet.id,
          "stop_id" => stop.id,
          "purchase_date" => ~U[2026-03-16 23:10:00Z]
        })

      stop_id = stop.id
      trip_id = trip.id

      assert [
               %{
                 id: ^stop_id,
                 trip_id: ^trip_id,
                 store_name: "Manual Store Name",
                 items: [%{name: "Receipt Repro Item"}]
               }
             ] = Inventory.list_trip_receipts(household_id)
    end
  end

  describe "user preferences" do
    test "normalizes corrupted dashboard widget types on read" do
      user = MegaPlanner.AccountsFixtures.user_fixture()

      Repo.insert!(%UserPreferences{
        user_id: user.id,
        nav_order: [],
        dashboard_widgets: [
          %{
            "id" => @corrupted_inventory_widget,
            "type" => @corrupted_inventory_widget,
            "visible" => true,
            "x" => 1,
            "y" => 0,
            "w" => 1,
            "h" => 10,
            "size" => "small",
            "minW" => 1,
            "minH" => 6
          }
        ],
        theme: "system",
        settings: %{}
      })

      prefs = Accounts.get_or_create_preferences(user.id)

      assert [
               %{
                 "id" => "inventory_status",
                 "type" => "inventory_status"
               }
             ] = prefs.dashboard_widgets

      assert [
               %{
                 "id" => "inventory_status",
                 "type" => "inventory_status"
               }
             ] =
               Repo.get_by!(UserPreferences, user_id: user.id).dashboard_widgets
    end
  end
end
