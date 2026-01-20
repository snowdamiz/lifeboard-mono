defmodule MegaPlanner.Repo.Migrations.CreatePurchases do
  use Ecto.Migration

  def change do
    create table(:purchases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all), null: false
      add :stop_id, references(:stops, type: :binary_id, on_delete: :nilify_all)
      add :budget_entry_id, references(:budget_entries, type: :binary_id, on_delete: :delete_all), null: false
      add :brand, :string, null: false
      add :item, :string, null: false
      add :unit_measurement, :string
      add :count, :decimal, precision: 12, scale: 2
      add :price_per_count, :decimal, precision: 12, scale: 2
      add :units, :decimal, precision: 12, scale: 2
      add :price_per_unit, :decimal, precision: 12, scale: 2
      add :taxable, :boolean, default: false
      add :total_price, :decimal, precision: 12, scale: 2, null: false
      add :store_code, :string
      add :item_name, :string

      timestamps(type: :utc_datetime)
    end

    create index(:purchases, [:household_id])
    create index(:purchases, [:stop_id])
    create index(:purchases, [:budget_entry_id])
    create index(:purchases, [:brand])
    create index(:purchases, [:item])
  end
end
