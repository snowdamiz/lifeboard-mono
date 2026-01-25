defmodule MegaPlanner.Repo.Migrations.CreateTextTemplates do
  use Ecto.Migration

  def change do
    create table(:text_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :household_id, references(:households, on_delete: :delete_all, type: :binary_id), null: false
      add :field_type, :string, null: false
      add :value, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:text_templates, [:household_id, :field_type])
    create unique_index(:text_templates, [:household_id, :field_type, :value])
  end
end
