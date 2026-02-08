defmodule MegaPlanner.Repo.Migrations.AddDefaultCountUnitToBrands do
  use Ecto.Migration

  def change do
    alter table(:brands) do
      add :default_count_unit, :string
    end
  end
end
