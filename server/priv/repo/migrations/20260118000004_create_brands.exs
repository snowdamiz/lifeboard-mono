defmodule MegaPlanner.Repo.Migrations.CreateBrands do
  use Ecto.Migration

  def change do
    create table(:brands, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :default_item, :string
      add :default_unit_measurement, :string
      add :default_tags, {:array, :binary_id}, default: []
      add :image_url, :string

      timestamps(type: :utc_datetime)
    end

    create index(:brands, [:household_id])
    create unique_index(:brands, [:household_id, :name])
  end
end
