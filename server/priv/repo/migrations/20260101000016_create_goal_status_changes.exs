defmodule MegaPlanner.Repo.Migrations.CreateGoalStatusChanges do
  use Ecto.Migration

  def change do
    create table(:goal_status_changes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :goal_id, references(:goals, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :nilify_all, type: :binary_id)

      add :from_status, :string
      add :to_status, :string, null: false
      add :notes, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:goal_status_changes, [:goal_id])
    create index(:goal_status_changes, [:goal_id, :inserted_at])
  end
end

