defmodule MegaPlanner.Households.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending accepted declined expired)

  schema "household_invitations" do
    field :email, :string
    field :token, :string
    field :status, :string, default: "pending"
    field :expires_at, :utc_datetime

    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :inviter, MegaPlanner.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :token, :status, :expires_at, :household_id, :inviter_id])
    |> validate_required([:email, :token, :status, :expires_at, :household_id, :inviter_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:token)
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:inviter_id)
  end

  @doc false
  def status_changeset(invitation, status) do
    invitation
    |> cast(%{status: status}, [:status])
    |> validate_inclusion(:status, @statuses)
  end
end
