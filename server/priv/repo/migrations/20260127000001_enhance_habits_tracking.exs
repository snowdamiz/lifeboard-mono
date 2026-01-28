defmodule MegaPlanner.Repo.Migrations.EnhanceHabitsTracking do
  use Ecto.Migration

  def change do
    # Add scheduled_time and duration_minutes to habits table
    alter table(:habits) do
      add :scheduled_time, :time
      add :duration_minutes, :integer
    end

    # Add status and not_today_reason to habit_completions table
    alter table(:habit_completions) do
      add :status, :string, default: "completed", null: false
      add :not_today_reason, :text
    end

    # Add index on status for efficient querying
    create index(:habit_completions, [:status])
  end
end
