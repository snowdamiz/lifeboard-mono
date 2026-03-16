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
    |> validate_change(:household_id, fn :household_id, id ->
      if MegaPlanner.Repo.get(MegaPlanner.Households.Household, id),
        do: [],
        else: [household_id: "does not exist"]
    end)
    |> validate_change(:user_id, fn :user_id, id ->
      if MegaPlanner.Repo.get(MegaPlanner.Accounts.User, id),
        do: [],
        else: [user_id: "does not exist"]
    end)
  end
end
