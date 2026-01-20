defmodule MegaPlanner.Repo.Migrations.CreatePurchasesTags do
  use Ecto.Migration

  def change do
    create table(:purchases_tags, primary_key: false) do
      add :purchase_id, references(:purchases, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create index(:purchases_tags, [:purchase_id])
    create index(:purchases_tags, [:tag_id])
    create unique_index(:purchases_tags, [:purchase_id, :tag_id])
  end
end
