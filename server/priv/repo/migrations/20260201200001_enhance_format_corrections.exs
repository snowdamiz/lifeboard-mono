defmodule MegaPlanner.Repo.Migrations.EnhanceFormatCorrections do
  use Ecto.Migration

  def change do
    alter table(:format_corrections) do
      add :corrected_unit, :string
      add :corrected_quantity, :integer
      add :preference_notes, :map, default: %{}
    end
  end
end
