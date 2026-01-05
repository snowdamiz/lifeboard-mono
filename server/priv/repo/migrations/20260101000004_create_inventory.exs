defmodule MegaPlanner.Repo.Migrations.CreateInventory do
  use Ecto.Migration

  def change do
    create table(:inventory_sheets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :columns, :map, default: %{}
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:inventory_sheets, [:user_id])

    create table(:inventory_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :quantity, :integer, default: 0
      add :min_quantity, :integer, default: 0
      add :is_necessity, :boolean, default: false
      add :store, :string
      add :custom_fields, :map, default: %{}
      add :sheet_id, references(:inventory_sheets, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:inventory_items, [:sheet_id])

    create table(:shopping_list_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :quantity_needed, :integer, default: 1
      add :purchased, :boolean, default: false
      add :inventory_item_id, references(:inventory_items, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:shopping_list_items, [:user_id])
    create index(:shopping_list_items, [:inventory_item_id])
    create unique_index(:shopping_list_items, [:user_id, :inventory_item_id], where: "purchased = false")
  end
end
