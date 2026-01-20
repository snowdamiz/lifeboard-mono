defmodule MegaPlanner.Repo.Migrations.CreateDrivers do
  use Ecto.Migration

  def change do
    create table(:drivers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :household_id, references(:households, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:drivers, [:household_id])
    create index(:drivers, [:user_id])
    
    alter table(:trips) do
      add :driver_id, references(:drivers, on_delete: :nilify_all, type: :binary_id)
    end

    create index(:trips, [:driver_id])
  end
end
