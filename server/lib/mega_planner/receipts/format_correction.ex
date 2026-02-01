defmodule MegaPlanner.Receipts.FormatCorrection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "format_corrections" do
    field :raw_text, :string
    field :corrected_brand, :string
    field :corrected_item, :string
    field :match_type, :string, default: "exact"

    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(correction, attrs) do
    correction
    |> cast(attrs, [:raw_text, :corrected_brand, :corrected_item, :match_type, :household_id])
    |> validate_required([:raw_text, :household_id])
    |> validate_inclusion(:match_type, ["exact", "fuzzy"])
    |> unique_constraint([:household_id, :raw_text])
    |> foreign_key_constraint(:household_id)
  end
end
