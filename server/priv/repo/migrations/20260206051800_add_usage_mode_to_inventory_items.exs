defmodule MegaPlanner.Repo.Migrations.AddUsageModeToInventoryItems do
  use Ecto.Migration

  def change do
    alter table(:inventory_items) do
      # "count" = consumed by individual count/weight (batteries, potatoes)
      # "quantity" = consumed as whole unit (couch, TV)
      add :usage_mode, :string, default: "count"
    end
  end
end
