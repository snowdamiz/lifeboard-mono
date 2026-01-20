defmodule MegaPlanner.Repo.Migrations.CreateUnits do
  use Ecto.Migration

  def change do
    create table(:units, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :household_id, references(:households, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:units, [:household_id])
    create unique_index(:units, [:household_id, :name], name: :units_household_id_name_index)
  end
end
