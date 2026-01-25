defmodule MegaPlanner.Repo.Migrations.CreateMilestoneTemplates do
  use Ecto.Migration

  def change do
    create table(:milestone_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :household_id, references(:households, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:milestone_templates, [:household_id])
    create unique_index(:milestone_templates, [:household_id, :title])
  end
end
