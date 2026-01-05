defmodule MegaPlanner.Repo.Migrations.CreateGoals do
  use Ecto.Migration

  def change do
    # Goals
    create table(:goals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      add :title, :string, null: false
      add :description, :text
      add :target_date, :date
      add :status, :string, default: "not_started"
      add :category, :string
      add :progress, :integer, default: 0
      add :linked_task_ids, {:array, :binary_id}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:goals, [:user_id])
    create index(:goals, [:user_id, :status])

    # Goal milestones
    create table(:goal_milestones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :goal_id, references(:goals, on_delete: :delete_all, type: :binary_id), null: false

      add :title, :string, null: false
      add :completed, :boolean, default: false
      add :completed_at, :utc_datetime
      add :position, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:goal_milestones, [:goal_id])
  end
end
