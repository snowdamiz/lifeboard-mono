defmodule MegaPlanner.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :name, :string
    field :avatar_url, :string
    field :provider, :string
    field :provider_id, :string

    # Household association
    belongs_to :household, MegaPlanner.Households.Household

    # Associations
    has_many :tasks, MegaPlanner.Calendar.Task
    has_many :inventory_sheets, MegaPlanner.Inventory.Sheet
    has_many :budget_sources, MegaPlanner.Budget.Source
    has_many :notebooks, MegaPlanner.Notes.Notebook
    has_many :tags, MegaPlanner.Tags.Tag

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar_url, :provider, :provider_id, :household_id])
    |> validate_required([:email, :provider, :provider_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint(:email)
    |> unique_constraint([:provider, :provider_id])
    |> foreign_key_constraint(:household_id)
  end
end
