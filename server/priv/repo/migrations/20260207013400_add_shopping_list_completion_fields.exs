defmodule MegaPlanner.Repo.Migrations.AddShoppingListCompletionFields do
  use Ecto.Migration

  def change do
    alter table(:shopping_lists) do
      add :status, :string, default: "active"
    end

    alter table(:shopping_list_items) do
      add :completed_at, :utc_datetime
    end
  end
end
