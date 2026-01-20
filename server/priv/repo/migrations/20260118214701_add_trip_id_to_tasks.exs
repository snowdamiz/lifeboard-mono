defmodule MegaPlanner.Repo.Migrations.AddTripIdToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :trip_id, references(:trips, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:tasks, [:trip_id])
  end
end
