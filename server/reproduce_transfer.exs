# server/reproduce_transfer.exs
import Ecto.Query

# Start apps
[:postgrex, :ecto_sql] |> Enum.each(&Application.ensure_all_started/1)

# Start Repo if not started
IO.puts("Starting Repo...")
case MegaPlanner.Repo.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
  e -> IO.inspect(e, label: "Failed to start repo")
end

alias MegaPlanner.Repo
alias MegaPlanner.Inventory
alias MegaPlanner.Accounts.User

# We need to manually start the Inventory context if it has GenServers?
# No, mostly it's just Ecto calls.

# --- Helper Functions ---
defmodule Helper do
  def get_first_household_and_user do
    # Get a user and their household
    user = Repo.one(from u in User, limit: 1)
    if user do
      {user.household_id, user.id}
    else
      {nil, nil}
    end
  end

  def setup_test_data(household_id, user_id) do
    IO.puts("Setting up test data for Household #{household_id}, User #{user_id}...")
    
    # 1. Create Source Sheet "Purchases"
    {:ok, source_sheet} = case Repo.get_by(Inventory.Sheet, household_id: household_id, name: "Purchases") do
      nil -> Inventory.create_sheet(%{"name" => "Purchases", "household_id" => household_id, "user_id" => user_id})
      sheet -> {:ok, sheet}
    end

    # 2. Create Target Sheet "Pantry"
    {:ok, target_sheet} = case Repo.get_by(Inventory.Sheet, household_id: household_id, name: "Pantry") do
      nil -> Inventory.create_sheet(%{"name" => "Pantry", "household_id" => household_id, "user_id" => user_id})
      sheet -> {:ok, sheet}
    end

    # 3. Create Item in Source
    # Using a random name to avoid collisions if run multiple times
    item_name = "Debug Transfer Item #{System.unique_integer([:positive])}"
    IO.puts("Creating item: #{item_name}")
    
    case Inventory.create_item(%{
      "name" => item_name,
      "brand" => "DebugBrand",
      "quantity" => 5,
      "sheet_id" => source_sheet.id,
      "min_quantity" => 1
    }) do
      {:ok, item} -> 
        # 4. Create Linked Shopping List Item
        case Inventory.create_shopping_list(%{"name" => "Debug List #{System.unique_integer([:positive])}", "household_id" => household_id, "user_id" => user_id}) do
          {:ok, list} ->
             case Inventory.create_shopping_item(%{
                "shopping_list_id" => list.id,
                "inventory_item_id" => item.id,
                "quantity_needed" => 1,
                "household_id" => household_id,
                "user_id" => user_id # Include user_id
            }) do
              {:ok, _sli} -> 
                # Re-fetch everything to be safe
                item = Inventory.get_item(item.id)
                source_sheet = Inventory.get_sheet(source_sheet.id)
                target_sheet = Inventory.get_sheet(target_sheet.id)
                {:ok, item, source_sheet, target_sheet}
              {:error, cs} -> 
                 IO.puts("Failed to create shopping item: #{inspect(cs.errors)}")
                 {:error, :create_shopping_item}
            end
          {:error, cs} ->
             IO.puts("Failed to create shopping list: #{inspect(cs.errors)}")
             {:error, :create_shopping_list}
        end
      {:error, cs} ->
        IO.puts("Failed to create item: #{inspect(cs.errors)}")
        {:error, :create_item}
    end
  end
end

# --- Main Execution ---


# Helper to log to file
defmodule FileLogger do
  def log(msg) do
    File.write!("repro_result.txt", msg <> "\n", [:append])
    IO.puts(msg)
  end
end

# --- Main Execution ---

FileLogger.log("\n=== Starting Reproduction Script ===")

{household_id, user_id} = Helper.get_first_household_and_user()

if household_id && user_id do
  FileLogger.log("Found Household ID: #{household_id} | User ID: #{user_id}")
  
  case Helper.setup_test_data(household_id, user_id) do
    {:ok, item, source_sheet, target_sheet} ->
      FileLogger.log("Created Source Item: #{item.name} (ID: #{item.id}) in '#{source_sheet.name}'")
      FileLogger.log("Target Sheet: '#{target_sheet.name}' (ID: #{target_sheet.id})")
      
      FileLogger.log("--- Attempting Transfer (Partial Quantity: 2) ---")
      case Inventory.transfer_item(item.id, target_sheet.id, 2) do
        {:ok, :ok} -> FileLogger.log("SUCCESS: Partial transfer completed.")
        error -> FileLogger.log("FAILURE: Partial transfer failed. Reason: #{inspect(error)}")
      end
      
      # Reload item to check quantity
      updated_item = Inventory.get_item(item.id)
      # Handle nil item just in case
      if updated_item do
        FileLogger.log("Source Item Quantity after Partial: #{updated_item.quantity} (Expected: 3)")
      else
        FileLogger.log("FAILURE: Source item vanished after partial transfer!")
      end
      
      FileLogger.log("--- Attempting Transfer (Remaining Quantity: 3 - Should Delete Source) ---")
      case Inventory.transfer_item(item.id, target_sheet.id, 3) do
        {:ok, :ok} -> FileLogger.log("SUCCESS: Full transfer completed.")
        error -> FileLogger.log("FAILURE: Full transfer failed. Reason: #{inspect(error)}")
      end

      # Check if deleted
      final_item = Inventory.get_item(item.id)
      if final_item == nil do
         FileLogger.log("SUCCESS: Source item correctly deleted from DB.")
      else
         FileLogger.log("FAILURE: Source item still exists with quantity: #{final_item.quantity}")
      end
    
    error -> 
      FileLogger.log("Setup failed: #{inspect(error)}")
  end

else
  FileLogger.log("No households or users found to test with.")
end

FileLogger.log("=== Script Complete ===")

