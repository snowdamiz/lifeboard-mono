defmodule MegaPlanner.Goals.MilestoneTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "milestone_templates" do
    field :title, :string
    belongs_to :household, MegaPlanner.Households.Household

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(milestone_template, attrs) do
    milestone_template
    |> cast(attrs, [:title, :household_id])
    |> validate_required([:title, :household_id])
    |> unique_constraint([:household_id, :title])
  end
end
