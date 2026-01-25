defmodule MegaPlanner.Templates.TextTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "text_templates" do
    field :field_type, :string
    field :value, :string
    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(text_template, attrs) do
    text_template
    |> cast(attrs, [:field_type, :value, :household_id])
    |> validate_required([:field_type, :value, :household_id])
    |> unique_constraint([:household_id, :field_type, :value])
  end
end
