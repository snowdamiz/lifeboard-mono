defmodule MegaPlanner.Repo.Migrations.AddUnitQuantityToFormatCorrections do
  use Ecto.Migration

  def change do
    alter table(:format_corrections) do
      add :corrected_unit_quantity, :decimal
    end
  end
end
