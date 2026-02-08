defmodule MegaPlanner.Repo.Migrations.RemovePurchaseBrandItemUnique do
  use Ecto.Migration

  def up do
    drop_if_exists index(:purchases, [:stop_id, :brand, :item], name: :purchases_stop_brand_item_unique)
  end

  def down do
    create unique_index(:purchases, [:stop_id, :brand, :item],
      where: "stop_id IS NOT NULL",
      name: :purchases_stop_brand_item_unique)
  end
end
