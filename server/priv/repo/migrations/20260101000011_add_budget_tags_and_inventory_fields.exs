defmodule MegaPlanner.Repo.Migrations.AddBudgetTagsAndInventoryFields do
  use Ecto.Migration

  def change do
    # Create budget_sources_tags join table for proper tag association
    create table(:budget_sources_tags, primary_key: false) do
      add :budget_source_id, references(:budget_sources, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:budget_sources_tags, [:budget_source_id, :tag_id])
    create index(:budget_sources_tags, [:tag_id])

    # Add unit_of_measure and brand to inventory items
    alter table(:inventory_items) do
      add :unit_of_measure, :string
      add :brand, :string
    end

    # Create inventory_items_tags join table for tagging inventory items
    create table(:inventory_items_tags, primary_key: false) do
      add :inventory_item_id, references(:inventory_items, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:inventory_items_tags, [:inventory_item_id, :tag_id])
    create index(:inventory_items_tags, [:tag_id])
  end
end
