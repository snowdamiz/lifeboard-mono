defmodule MegaPlanner.Goals.HabitInventoryTest do
  @moduledoc """
  Tests for HabitInventory schema and CRUD operations.
  Tests coverage_mode, linked_inventory_ids, day_start_time, and day_end_time fields.
  """
  use ExUnit.Case, async: true

  alias MegaPlanner.Repo
  alias MegaPlanner.Goals
  alias MegaPlanner.Goals.HabitInventory
  alias MegaPlanner.Accounts

  setup do
    # Start a sandbox for database transactions
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    # Create a test household
    {:ok, household} = Accounts.create_household(%{"name" => "Test Household"})

    %{household: household}
  end

  describe "create_habit_inventory/1" do
    test "creates inventory with default coverage_mode as partial_day", %{household: household} do
      attrs = %{
        "name" => "Morning Routine",
        "color" => "#10b981",
        "household_id" => household.id
      }

      {:ok, inventory} = Goals.create_habit_inventory(attrs)

      assert inventory.name == "Morning Routine"
      assert inventory.color == "#10b981"
      assert inventory.coverage_mode == :partial_day
      assert inventory.linked_inventory_ids == []
      assert inventory.day_start_time == nil
      assert inventory.day_end_time == nil
    end

    test "creates whole_day inventory with explicit coverage_mode", %{household: household} do
      attrs = %{
        "name" => "Full Day Schedule",
        "color" => "#3b82f6",
        "household_id" => household.id,
        "coverage_mode" => "whole_day"
      }

      {:ok, inventory} = Goals.create_habit_inventory(attrs)

      assert inventory.coverage_mode == :whole_day
    end

    test "creates inventory with day_start_time and day_end_time", %{household: household} do
      attrs = %{
        "name" => "Work Hours",
        "color" => "#f59e0b",
        "household_id" => household.id,
        "coverage_mode" => "partial_day",
        "day_start_time" => "09:00:00",
        "day_end_time" => "17:00:00"
      }

      {:ok, inventory} = Goals.create_habit_inventory(attrs)

      assert inventory.day_start_time == ~T[09:00:00]
      assert inventory.day_end_time == ~T[17:00:00]
    end
  end

  describe "update_habit_inventory/2" do
    test "updates coverage_mode from partial_day to whole_day", %{household: household} do
      {:ok, inventory} = Goals.create_habit_inventory(%{
        "name" => "Test",
        "household_id" => household.id
      })

      {:ok, updated} = Goals.update_habit_inventory(inventory, %{"coverage_mode" => "whole_day"})

      assert updated.coverage_mode == :whole_day
    end

    test "updates linked_inventory_ids", %{household: household} do
      # Create two inventories
      {:ok, main_inv} = Goals.create_habit_inventory(%{
        "name" => "Main",
        "household_id" => household.id,
        "coverage_mode" => "whole_day"
      })

      {:ok, partial_inv} = Goals.create_habit_inventory(%{
        "name" => "Partial",
        "household_id" => household.id,
        "coverage_mode" => "partial_day"
      })

      # Link partial to main
      {:ok, updated} = Goals.update_habit_inventory(main_inv, %{
        "linked_inventory_ids" => [partial_inv.id]
      })

      assert updated.linked_inventory_ids == [partial_inv.id]
    end

    test "updates day_start_time and day_end_time", %{household: household} do
      {:ok, inventory} = Goals.create_habit_inventory(%{
        "name" => "Test",
        "household_id" => household.id
      })

      {:ok, updated} = Goals.update_habit_inventory(inventory, %{
        "day_start_time" => "06:00:00",
        "day_end_time" => "22:00:00"
      })

      assert updated.day_start_time == ~T[06:00:00]
      assert updated.day_end_time == ~T[22:00:00]
    end

    test "clears day_start_time and day_end_time with nil", %{household: household} do
      {:ok, inventory} = Goals.create_habit_inventory(%{
        "name" => "Test",
        "household_id" => household.id,
        "day_start_time" => "09:00:00",
        "day_end_time" => "17:00:00"
      })

      {:ok, updated} = Goals.update_habit_inventory(inventory, %{
        "day_start_time" => nil,
        "day_end_time" => nil
      })

      assert updated.day_start_time == nil
      assert updated.day_end_time == nil
    end
  end

  describe "list_habit_inventories/1" do
    test "returns all inventories for a household with new fields", %{household: household} do
      # Create inventories with different modes
      {:ok, _partial} = Goals.create_habit_inventory(%{
        "name" => "Morning",
        "household_id" => household.id,
        "coverage_mode" => "partial_day",
        "day_start_time" => "06:00:00",
        "day_end_time" => "09:00:00"
      })

      {:ok, _whole} = Goals.create_habit_inventory(%{
        "name" => "Full Day",
        "household_id" => household.id,
        "coverage_mode" => "whole_day"
      })

      inventories = Goals.list_habit_inventories(household.id)

      assert length(inventories) == 2
      
      # Check that the inventories have the expected fields
      partial = Enum.find(inventories, &(&1.name == "Morning"))
      whole = Enum.find(inventories, &(&1.name == "Full Day"))

      assert partial.coverage_mode == :partial_day
      assert partial.day_start_time == ~T[06:00:00]
      assert whole.coverage_mode == :whole_day
    end
  end
end
