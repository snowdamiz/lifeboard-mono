# Test script to verify HabitInventory schema changes
# Run with: mix run test_habit_inventory.exs

IO.puts("=== Testing HabitInventory Schema Changes ===\n")

alias MegaPlanner.Repo
alias MegaPlanner.Goals.HabitInventory
import Ecto.Query

# Test 1: Verify new fields exist in schema
IO.puts("Test 1: Schema fields verification")
fields = HabitInventory.__schema__(:fields)
required_fields = [:coverage_mode, :linked_inventory_ids, :day_start_time, :day_end_time]

Enum.each(required_fields, fn field ->
  if field in fields do
    IO.puts("  ✓ Field '#{field}' exists")
  else
    IO.puts("  ✗ Field '#{field}' MISSING!")
  end
end)

# Test 2: Verify changeset accepts new fields
IO.puts("\nTest 2: Changeset validation")
test_attrs = %{
  "name" => "Test Inventory",
  "household_id" => Ecto.UUID.generate(),
  "coverage_mode" => "whole_day",
  "linked_inventory_ids" => [Ecto.UUID.generate()],
  "day_start_time" => "09:00:00",
  "day_end_time" => "17:00:00"
}

changeset = HabitInventory.changeset(%HabitInventory{}, test_attrs)

if changeset.valid? do
  IO.puts("  ✓ Changeset is valid with new fields")
else
  IO.puts("  ✗ Changeset validation failed: #{inspect(changeset.errors)}")
end

# Test 3: Verify coverage_mode validation
IO.puts("\nTest 3: Coverage mode validation")

valid_modes = ["whole_day", "partial_day"]
Enum.each(valid_modes, fn mode ->
  cs = HabitInventory.changeset(%HabitInventory{}, %{
    "name" => "Test",
    "household_id" => Ecto.UUID.generate(),
    "coverage_mode" => mode
  })
  if cs.valid? do
    IO.puts("  ✓ Mode '#{mode}' is valid")
  else
    IO.puts("  ✗ Mode '#{mode}' rejected: #{inspect(cs.errors)}")
  end
end)

# Test invalid mode
invalid_cs = HabitInventory.changeset(%HabitInventory{}, %{
  "name" => "Test",
  "household_id" => Ecto.UUID.generate(),
  "coverage_mode" => "invalid_mode"
})
if not invalid_cs.valid? do
  IO.puts("  ✓ Invalid mode 'invalid_mode' correctly rejected")
else
  IO.puts("  ✗ Invalid mode 'invalid_mode' was accepted (should be rejected)")
end

# Test 4: Verify default values
IO.puts("\nTest 4: Default values")
default_cs = HabitInventory.changeset(%HabitInventory{}, %{
  "name" => "Default Test",
  "household_id" => Ecto.UUID.generate()
})

changes = default_cs.changes
schema_defaults = %HabitInventory{}

IO.puts("  Default coverage_mode: #{schema_defaults.coverage_mode || "nil"}")
IO.puts("  Default linked_inventory_ids: #{inspect(schema_defaults.linked_inventory_ids)}")

# Test 5: Check database column existence
IO.puts("\nTest 5: Database column check")
try do
  query = from i in HabitInventory, 
    select: {i.coverage_mode, i.linked_inventory_ids, i.day_start_time, i.day_end_time},
    limit: 1
  Repo.all(query)
  IO.puts("  ✓ Query with new columns executed successfully")
rescue
  e ->
    IO.puts("  ✗ Query failed: #{inspect(e)}")
end

IO.puts("\n=== Tests Complete ===")
