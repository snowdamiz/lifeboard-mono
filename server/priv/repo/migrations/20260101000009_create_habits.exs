defmodule MegaPlanner.Repo.Migrations.CreateHabits do
  use Ecto.Migration

  def change do
    # Habits
    create table(:habits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      add :name, :string, null: false
      add :description, :text
      add :frequency, :string, default: "daily"  # daily, weekly
      add :days_of_week, {:array, :integer}      # 0-6 for weekly habits
      add :reminder_time, :time
      add :color, :string, default: "#10b981"

      add :streak_count, :integer, default: 0
      add :longest_streak, :integer, default: 0
      add :last_completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:habits, [:user_id])

    # Habit completions
    create table(:habit_completions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :habit_id, references(:habits, on_delete: :delete_all, type: :binary_id), null: false

      add :completed_at, :utc_datetime, null: false
      add :date, :date, null: false  # For easy querying by date

      timestamps(type: :utc_datetime)
    end

    create index(:habit_completions, [:habit_id])
    # Use unique index for habit_id + date to ensure one completion per day per habit
    create unique_index(:habit_completions, [:habit_id, :date])
  end
end
