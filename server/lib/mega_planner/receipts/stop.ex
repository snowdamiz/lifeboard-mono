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

    belongs_to :trip, MegaPlanner.Receipts.Trip
    belongs_to :store, MegaPlanner.Receipts.Store
    has_many :purchases, MegaPlanner.Receipts.Purchase

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(stop, attrs) do
    stop
    |> cast(attrs, [:store_name, :store_address, :notes, :position, :trip_id, :store_id])
    |> validate_required([:trip_id, :position])
    |> foreign_key_constraint(:trip_id)
    |> foreign_key_constraint(:store_id)
  end
end
