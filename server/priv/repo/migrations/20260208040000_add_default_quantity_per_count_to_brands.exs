defmodule MegaPlanner.Repo.Migrations.AddDefaultQuantityPerCountToBrands do
  use Ecto.Migration

  def change do
    alter table(:brands) do
      add :default_quantity_per_count, :decimal
      add :default_unit_measurement_per_count, :string
    end
  end
end
