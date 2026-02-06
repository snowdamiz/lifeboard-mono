defmodule MegaPlanner.Repo.Migrations.AddCountUnitField do
  use Ecto.Migration

  def change do
    alter table(:purchases) do
      add :count_unit, :string
    end

    alter table(:inventory_items) do
      add :count_unit, :string
    end
  end
end
