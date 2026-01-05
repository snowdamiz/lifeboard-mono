defmodule MegaPlanner.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @notification_types ~w(task_due low_inventory budget_warning habit_reminder system)
  @link_types ~w(task inventory_item budget_entry habit page)

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :message, :string
    field :data, :map, default: %{}
    field :read, :boolean, default: false
    field :read_at, :utc_datetime
    field :link_type, :string
    field :link_id, :binary_id

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :title, :message, :data, :read, :read_at, :link_type, :link_id, :user_id, :household_id])
    |> validate_required([:type, :title, :user_id, :household_id])
    |> validate_inclusion(:type, @notification_types)
    |> validate_inclusion(:link_type, @link_types ++ [nil])
    |> foreign_key_constraint(:household_id)
  end

  def mark_read_changeset(notification) do
    notification
    |> change(%{read: true, read_at: DateTime.utc_now()})
  end
end
