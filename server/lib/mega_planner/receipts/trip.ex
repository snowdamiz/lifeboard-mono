defmodule MegaPlanner.Receipts.Trip do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "trips" do
    field :trip_start, :utc_datetime
    field :trip_end, :utc_datetime
    field :notes, :string

    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :driver, MegaPlanner.Receipts.Driver, foreign_key: :driver_id
    has_many :stops, MegaPlanner.Receipts.Stop

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(trip, attrs) do
    trip
    |> cast(attrs, [:trip_start, :trip_end, :notes, :household_id, :user_id, :driver_id])
    |> validate_required([:household_id, :user_id])
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:driver_id)
  end
end
