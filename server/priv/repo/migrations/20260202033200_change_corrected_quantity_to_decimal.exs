defmodule MegaPlanner.Repo.Migrations.ChangeCorrectedQuantityToDecimal do
  use Ecto.Migration

  def change do
    alter table(:format_corrections) do
      modify :corrected_quantity, :decimal, from: :integer
    end
  end
end
