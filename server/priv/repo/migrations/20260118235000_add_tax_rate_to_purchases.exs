defmodule MegaPlanner.Repo.Migrations.AddTaxRateToPurchases do
  use Ecto.Migration

  def change do
    alter table(:purchases) do
      add :tax_rate, :decimal
    end
  end
end
