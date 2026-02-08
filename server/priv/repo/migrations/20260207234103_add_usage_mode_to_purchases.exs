defmodule MegaPlanner.Repo.Migrations.AddUsageModeToPurchases do
  use Ecto.Migration

  def change do
    alter table(:purchases) do
      add :usage_mode, :string, default: "count"
    end
  end
end
