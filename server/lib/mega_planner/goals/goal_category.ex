defmodule MegaPlanner.Goals.GoalCategory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "goal_categories" do
    field :name, :string
    field :color, :string, default: "#6366f1"
    field :position, :integer, default: 0

    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :parent, __MODULE__, foreign_key: :parent_id
    has_many :subcategories, __MODULE__, foreign_key: :parent_id
    has_many :goals, MegaPlanner.Goals.Goal

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :color, :position, :household_id, :parent_id])
    |> validate_required([:name, :household_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a valid hex color")
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:parent_id)
    |> unique_constraint([:household_id, :name, :parent_id], name: :goal_categories_household_name_parent_unique)
  end
end

