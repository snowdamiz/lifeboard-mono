defmodule MegaPlanner.Repo.Migrations.CreateFormatCorrections do
  use Ecto.Migration

  def change do
    create table(:format_corrections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all), null: false
      add :raw_text, :string, null: false
      add :corrected_brand, :string
      add :corrected_item, :string
      add :match_type, :string, default: "exact"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:format_corrections, [:household_id, :raw_text])
    create index(:format_corrections, [:household_id])
  end
end
