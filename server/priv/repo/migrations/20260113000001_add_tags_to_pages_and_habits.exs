defmodule MegaPlanner.Repo.Migrations.AddTagsToPagesAndHabits do
  use Ecto.Migration

  def change do
    # Join table for pages and tags
    create table(:pages_tags, primary_key: false) do
      add :page_id, references(:pages, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:pages_tags, [:page_id, :tag_id])
    create index(:pages_tags, [:tag_id])

    # Join table for habits and tags
    create table(:habits_tags, primary_key: false) do
      add :habit_id, references(:habits, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:habits_tags, [:habit_id, :tag_id])
    create index(:habits_tags, [:tag_id])
  end
end
