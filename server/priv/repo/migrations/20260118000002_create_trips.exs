defmodule MegaPlanner.Repo.Migrations.CreateTrips do
  use Ecto.Migration

  def change do
    create table(:trips, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :driver, :string
      add :trip_start, :utc_datetime
      add :trip_end, :utc_datetime
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:trips, [:household_id])
    create index(:trips, [:user_id])
    create index(:trips, [:trip_start])
  end
end
