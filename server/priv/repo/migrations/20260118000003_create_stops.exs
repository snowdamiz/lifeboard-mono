defmodule MegaPlanner.Repo.Migrations.CreateStops do
  use Ecto.Migration

  def change do
    create table(:stops, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :trip_id, references(:trips, type: :binary_id, on_delete: :delete_all), null: false
      add :store_id, references(:stores, type: :binary_id, on_delete: :nilify_all)
      add :store_name, :string
      add :store_address, :text
      add :notes, :text
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:stops, [:trip_id])
    create index(:stops, [:store_id])
    create index(:stops, [:trip_id, :position])
  end
end
