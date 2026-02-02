defmodule MegaPlanner.Receipts.FormatCorrection do
  @moduledoc """
  Stores user corrections to receipt parsing results.
  Used to learn from user preferences and apply corrections to future scans.
  
  The system learns:
  - Brand name preferences (e.g., "GV" → "Great Value")
  - Item name formatting (e.g., "WHOLE MILK 1GAL" → "Whole Milk")
  - Unit preferences (e.g., "GAL" → "Gallon")
  - Quantity interpretations
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "format_corrections" do
    field :raw_text, :string
    field :corrected_brand, :string
    field :corrected_item, :string
    field :corrected_unit, :string
    field :corrected_quantity, :decimal
    field :corrected_unit_quantity, :decimal
    field :match_type, :string, default: "exact"
    # Flexible storage for future learning patterns
    field :preference_notes, :map, default: %{}

    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(correction, attrs) do
    correction
    |> cast(attrs, [
      :raw_text, 
      :corrected_brand, 
      :corrected_item, 
      :corrected_unit,
      :corrected_quantity,
      :corrected_unit_quantity,
      :match_type, 
      :preference_notes,
      :household_id
    ])
    |> validate_required([:raw_text, :household_id])
    |> validate_inclusion(:match_type, ["exact", "fuzzy"])
    |> unique_constraint([:household_id, :raw_text])
    |> foreign_key_constraint(:household_id)
  end
end
