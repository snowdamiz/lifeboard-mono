defmodule MegaPlanner.Receipts.Stop do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stops" do
    field :store_name, :string
    field :store_address, :string
    field :notes, :string
    field :position, :integer
    field :time_arrived, :time
    field :time_left, :time

    belongs_to :trip, MegaPlanner.Receipts.Trip
    belongs_to :store, MegaPlanner.Receipts.Store
    has_many :purchases, MegaPlanner.Receipts.Purchase, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(stop, attrs) do
    stop
    |> cast(attrs, [:store_name, :store_address, :notes, :position, :trip_id, :store_id, :time_arrived, :time_left])
    |> validate_required([:trip_id, :position, :time_arrived, :time_left])
    |> foreign_key_constraint(:trip_id)
    |> foreign_key_constraint(:store_id)
    |> unique_constraint([:trip_id, :store_id],
       name: :stops_trip_store_unique,
       message: "This store is already part of the trip")
  end
end
