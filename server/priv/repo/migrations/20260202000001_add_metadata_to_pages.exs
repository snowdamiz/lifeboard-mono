defmodule MegaPlanner.Repo.Migrations.AddMetadataToPages do
  use Ecto.Migration

  def change do
    alter table(:pages) do
      add :metadata, :text
    end
  end
end
