defmodule MegaPlanner.Repo.Migrations.ExtendInventoryItems do
  use Ecto.Migration

  def change do
    alter table(:inventory_items) do
      add :count, :decimal, precision: 12, scale: 2
      add :price_per_count, :decimal, precision: 12, scale: 2
      add :price_per_unit, :decimal, precision: 12, scale: 2
      add :taxable, :boolean, default: false
      add :total_price, :decimal, precision: 12, scale: 2
      add :store_code, :string
      add :item_name, :string
    end

    alter table(:budget_entries) do
      add :purchase_id, references(:purchases, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:budget_entries, [:purchase_id])
  end
end
