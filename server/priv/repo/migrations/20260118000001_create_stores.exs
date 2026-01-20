defmodule MegaPlanner.Repo.Migrations.CreateStores do
  use Ecto.Migration

  def change do
    create table(:stores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :address, :text
      add :state, :string
      add :store_code, :string
      add :tax_rate, :decimal, precision: 5, scale: 4

      timestamps(type: :utc_datetime)
    end

    create index(:stores, [:household_id])
    create index(:stores, [:household_id, :name])
  end
end
