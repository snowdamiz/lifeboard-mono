defmodule MegaPlanner.Inventory.ShoppingList do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shopping_lists" do
    field :name, :string
    field :is_auto_generated, :boolean, default: false
    field :notes, :string
    field :status, :string, default: "active"

    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :user, MegaPlanner.Accounts.User
    has_many :items, MegaPlanner.Inventory.ShoppingListItem, on_delete: :delete_all
    many_to_many :tags, MegaPlanner.Tags.Tag, join_through: "shopping_lists_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :is_auto_generated, :notes, :status, :household_id, :user_id])
    |> validate_required([:name, :household_id])
    |> validate_inclusion(:status, ["active", "completed"])
    |> validate_length(:name, min: 1, max: 200)
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:household_id, :is_auto_generated],
        name: :shopping_lists_household_auto_generated_unique,
        message: "only one auto-generated list per household")
  end

  def tags_changeset(list, tags) do
    list
    |> change()
    |> put_assoc(:tags, tags)
  end
end

