defmodule MegaPlanner.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    # Notification preferences per user
    create table(:notification_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      # Task notifications
      add :task_due_enabled, :boolean, default: true
      add :task_due_hours_before, :integer, default: 24

      # Inventory notifications
      add :low_inventory_enabled, :boolean, default: true

      # Budget notifications
      add :budget_threshold_enabled, :boolean, default: true
      add :budget_threshold_percent, :integer, default: 80

      # Habit reminders
      add :habit_reminder_enabled, :boolean, default: true

      # Browser push
      add :push_enabled, :boolean, default: false
      add :push_subscription, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:notification_preferences, [:user_id])

    # In-app notifications
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      add :type, :string, null: false  # task_due, low_inventory, budget_warning, habit_reminder
      add :title, :string, null: false
      add :message, :text
      add :data, :map, default: %{}

      add :read, :boolean, default: false
      add :read_at, :utc_datetime

      add :link_type, :string  # task, inventory_item, budget_entry, habit
      add :link_id, :binary_id

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :read])
    create index(:notifications, [:user_id, :inserted_at])
  end
end
