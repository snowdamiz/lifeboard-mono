defmodule MegaPlanner.Repo.Migrations.AddTagsToEntities do
  use Ecto.Migration

  def change do
    # Inventory Sheets
    create table(:inventory_sheets_tags, primary_key: false) do
      add :sheet_id, references(:inventory_sheets, type: :binary_id, on_delete: :delete_all)
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all)
    end

    create unique_index(:inventory_sheets_tags, [:sheet_id, :tag_id])

    # Shopping Lists
    create table(:shopping_lists_tags, primary_key: false) do
      add :shopping_list_id, references(:shopping_lists, type: :binary_id, on_delete: :delete_all)
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all)
    end

    create unique_index(:shopping_lists_tags, [:shopping_list_id, :tag_id])

    # Budget Entries
    create table(:budget_entries_tags, primary_key: false) do
      add :entry_id, references(:budget_entries, type: :binary_id, on_delete: :delete_all)
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all)
    end

    create unique_index(:budget_entries_tags, [:entry_id, :tag_id])

    # Notes Notebooks
    create table(:notebooks_tags, primary_key: false) do
      add :notebook_id, references(:notebooks, type: :binary_id, on_delete: :delete_all)
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all)
    end

    create unique_index(:notebooks_tags, [:notebook_id, :tag_id])
  end
end
