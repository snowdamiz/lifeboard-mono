defmodule MegaPlanner.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tags" do
    field :name, :string
    field :color, :string, default: "#6366f1"

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    many_to_many :tasks, MegaPlanner.Calendar.Task, join_through: "tasks_tags"
    many_to_many :budget_sources, MegaPlanner.Budget.Source,
      join_through: "budget_sources_tags",
      join_keys: [tag_id: :id, budget_source_id: :id]
    many_to_many :inventory_items, MegaPlanner.Inventory.Item,
      join_through: "inventory_items_tags",
      join_keys: [tag_id: :id, inventory_item_id: :id]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :color, :user_id, :household_id])
    |> validate_required([:name, :user_id, :household_id])
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/, message: "must be a valid hex color")
    |> unique_constraint([:household_id, :name])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
  end
end
