defmodule MegaPlanner.Repo.Migrations.AddPurchaseDataToInventoryItems do
  use Ecto.Migration

  def change do
    alter table(:inventory_items) do
      add :purchase_id, references(:purchases, on_delete: :nothing, type: :binary_id)
      add :trip_id, references(:trips, on_delete: :nothing, type: :binary_id)
      add :stop_id, references(:stops, on_delete: :nothing, type: :binary_id)
      add :purchase_date, :utc_datetime
    end

    create index(:inventory_items, [:purchase_id])
  end
end
