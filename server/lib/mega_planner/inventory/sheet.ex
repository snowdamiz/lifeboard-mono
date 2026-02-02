defmodule MegaPlanner.Inventory.Sheet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory_sheets" do
    field :name, :string
    field :columns, :map, default: %{}

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    has_many :items, MegaPlanner.Inventory.Item, on_delete: :delete_all
    many_to_many :tags, MegaPlanner.Tags.Tag, join_through: "inventory_sheets_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sheet, attrs) do
    sheet
    |> cast(attrs, [:name, :columns, :user_id, :household_id])
    |> validate_required([:name, :user_id, :household_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
  end

  def tags_changeset(sheet, tags) do
    sheet
    |> change()
    |> put_assoc(:tags, tags)
  end
end
