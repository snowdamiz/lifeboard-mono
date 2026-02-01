defmodule MegaPlanner.Repo.Migrations.AddStoreImageUrl do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      add :image_url, :text  # TEXT type for base64 data URLs
    end
  end
end
