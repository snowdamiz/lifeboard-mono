defmodule MegaPlanner.Households.Household do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "households" do
    field :name, :string

    has_many :users, MegaPlanner.Accounts.User
    has_many :invitations, MegaPlanner.Households.Invitation

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(household, attrs) do
    household
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
  end
end
