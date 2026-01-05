defmodule MegaPlanner.Repo.Migrations.CreateHouseholds do
  use Ecto.Migration

  def change do
    # Create households table
    create table(:households, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string

      timestamps(type: :utc_datetime)
    end

    # Add household_id to users
    alter table(:users) do
      add :household_id, references(:households, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:users, [:household_id])
  end
end
