defmodule MegaPlanner.Repo.Migrations.ChangeQuantityToDecimal do
  use Ecto.Migration

  def up do
    # Change quantity and min_quantity from integer to decimal to preserve fractional values
    alter table(:inventory_items) do
      modify :quantity, :decimal, default: 0
      modify :min_quantity, :decimal, default: 0
    end
  end

  def down do
    alter table(:inventory_items) do
      modify :quantity, :integer, default: 0
      modify :min_quantity, :integer, default: 0
    end
  end
end
