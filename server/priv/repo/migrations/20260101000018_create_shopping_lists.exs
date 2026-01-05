defmodule MegaPlanner.Repo.Migrations.CreateShoppingLists do
  use Ecto.Migration

  def change do
    # Create shopping lists table
    create table(:shopping_lists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :household_id, references(:households, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :nilify_all, type: :binary_id)

      add :name, :string, null: false
      add :is_auto_generated, :boolean, default: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:shopping_lists, [:household_id])
    create unique_index(:shopping_lists, [:household_id, :is_auto_generated],
      where: "is_auto_generated = true",
      name: :shopping_lists_household_auto_generated_unique)

    # Add shopping_list_id to shopping_list_items
    alter table(:shopping_list_items) do
      add :shopping_list_id, references(:shopping_lists, on_delete: :delete_all, type: :binary_id)
      # Allow manual items without inventory_item reference
      modify :inventory_item_id, :binary_id, null: true
      # Add name for manual items
      add :name, :string
    end

    create index(:shopping_list_items, [:shopping_list_id])
  end
end

