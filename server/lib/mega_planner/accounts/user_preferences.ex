defmodule MegaPlanner.Accounts.UserPreferences do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_preferences" do
    field :nav_order, {:array, :string}, default: []
    field :dashboard_widgets, {:array, :map}, default: []
    field :theme, :string, default: "system"
    field :settings, :map, default: %{}

    belongs_to :user, MegaPlanner.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(preferences, attrs) do
    preferences
    |> cast(attrs, [:nav_order, :dashboard_widgets, :theme, :settings, :user_id])
    |> validate_required([:user_id])
    |> validate_inclusion(:theme, ["light", "dark", "system"])
    |> unique_constraint(:user_id)
    |> foreign_key_constraint(:user_id)
  end
end

