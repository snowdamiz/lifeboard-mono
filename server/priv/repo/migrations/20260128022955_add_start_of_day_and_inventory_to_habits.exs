defmodule MegaPlanner.Repo.Migrations.AddStartOfDayAndInventoryToHabits do
  use Ecto.Migration

  def change do
    # Create habit_inventories table for grouping habits
    create table(:habit_inventories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :color, :string, default: "#10b981"
      add :position, :integer, default: 0
      add :household_id, references(:households, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:habit_inventories, [:household_id])

    # Add new fields to habits table
    alter table(:habits) do
      add :is_start_of_day, :boolean, default: false
      add :inventory_id, references(:habit_inventories, on_delete: :nilify_all, type: :binary_id)
    end

    create index(:habits, [:inventory_id])
  end
end
