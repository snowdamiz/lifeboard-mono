defmodule MegaPlanner.Repo.Migrations.CreateGoalCategoriesAndTags do
  use Ecto.Migration

  def change do
    # Goal categories with support for subcategories (parent_id)
    create table(:goal_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :household_id, references(:households, on_delete: :delete_all, type: :binary_id), null: false
      add :parent_id, references(:goal_categories, on_delete: :nilify_all, type: :binary_id)

      add :name, :string, null: false
      add :color, :string, default: "#6366f1"
      add :position, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:goal_categories, [:household_id])
    create index(:goal_categories, [:parent_id])
    create unique_index(:goal_categories, [:household_id, :name, :parent_id], name: :goal_categories_household_name_parent_unique)

    # Add goal_category_id to goals (nullable, for migration from string category)
    alter table(:goals) do
      add :goal_category_id, references(:goal_categories, on_delete: :nilify_all, type: :binary_id)
    end

    create index(:goals, [:goal_category_id])

    # Create goals_tags join table
    create table(:goals_tags, primary_key: false) do
      add :goal_id, references(:goals, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:goals_tags, [:goal_id, :tag_id])
    create index(:goals_tags, [:tag_id])
  end
end

