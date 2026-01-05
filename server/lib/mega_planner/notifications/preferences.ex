defmodule MegaPlanner.Notifications.Preferences do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notification_preferences" do
    # Task notifications
    field :task_due_enabled, :boolean, default: true
    field :task_due_hours_before, :integer, default: 24

    # Inventory notifications
    field :low_inventory_enabled, :boolean, default: true

    # Budget notifications
    field :budget_threshold_enabled, :boolean, default: true
    field :budget_threshold_percent, :integer, default: 80

    # Habit reminders
    field :habit_reminder_enabled, :boolean, default: true

    # Browser push
    field :push_enabled, :boolean, default: false
    field :push_subscription, :map

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(preferences, attrs) do
    preferences
    |> cast(attrs, [
      :task_due_enabled, :task_due_hours_before,
      :low_inventory_enabled,
      :budget_threshold_enabled, :budget_threshold_percent,
      :habit_reminder_enabled,
      :push_enabled, :push_subscription,
      :user_id, :household_id
    ])
    |> validate_required([:user_id, :household_id])
    |> validate_number(:task_due_hours_before, greater_than: 0, less_than_or_equal_to: 168)
    |> validate_number(:budget_threshold_percent, greater_than: 0, less_than_or_equal_to: 100)
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
  end
end
