defmodule MegaPlanner.Repo.Migrations.AddHabitInventoryFields do
  use Ecto.Migration

  def change do
    alter table(:habit_inventories) do
      add :coverage_mode, :string, default: "partial_day"
      add :linked_inventory_ids, {:array, :binary_id}, default: []
      add :day_start_time, :time
      add :day_end_time, :time
    end
  end
end
