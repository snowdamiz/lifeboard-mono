defmodule MegaPlanner.Receipts.Trip do
  use Ecto.Schema
  import Ecto.Changeset
  import MegaPlanner.ChangesetConstraints, only: [sqlite_compatible_unique_constraint: 3]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "trips" do
    field :trip_start, :utc_datetime
    field :trip_end, :utc_datetime
    field :notes, :string

    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :driver, MegaPlanner.Receipts.Driver, foreign_key: :driver_id
    has_many :stops, MegaPlanner.Receipts.Stop, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(trip, attrs) do
    trip
    |> cast(attrs, [:trip_start, :trip_end, :notes, :household_id, :user_id, :driver_id])
    |> validate_required([:household_id, :user_id])
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
    |> validate_change(:driver_id, fn :driver_id, id ->
      if MegaPlanner.Repo.get(MegaPlanner.Receipts.Driver, id),
        do: [],
        else: [driver_id: "does not exist"]
    end)
    |> sqlite_compatible_unique_constraint([:trip_start, :household_id],
      name: :trips_start_household_unique,
      message: "A trip already exists for this start time"
    )
  end
end
