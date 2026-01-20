defmodule MegaPlanner.Receipts.Driver do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "drivers" do
    field :name, :string
    
    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :user, MegaPlanner.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(driver, attrs) do
    driver
    |> cast(attrs, [:name, :household_id, :user_id])
    |> validate_required([:name, :household_id])
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:user_id)
  end
end
