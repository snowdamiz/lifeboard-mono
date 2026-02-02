defmodule MegaPlanner.Receipts.TaxIndicatorMeaning do
  @moduledoc """
  Stores user-defined meanings for tax indicator codes on receipts.
  
  Different stores use different indicator codes:
  - Walmart: "N" = non-taxable food, "X" = taxable
  - Costco: "A" = taxable, blank = non-taxable
  - Target: "T" = taxable, "N" = non-taxable
  
  Users can correct the AI's interpretation, and those corrections
  are stored here to improve future receipt parsing for that store.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tax_indicator_meanings" do
    field :store_name, :string
    field :indicator, :string
    field :is_taxable, :boolean
    field :description, :string
    field :default_tax_rate, :decimal

    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(meaning, attrs) do
    meaning
    |> cast(attrs, [:store_name, :indicator, :is_taxable, :description, :default_tax_rate, :household_id])
    |> validate_required([:store_name, :indicator, :is_taxable, :household_id])
    |> validate_length(:indicator, max: 5)
    |> unique_constraint([:household_id, :store_name, :indicator],
       name: :tax_indicator_meanings_unique)
    |> foreign_key_constraint(:household_id)
  end
end
