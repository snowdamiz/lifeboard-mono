defmodule MegaPlanner.Budget.Source do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ["income", "expense"]

  schema "budget_sources" do
    field :name, :string
    field :type, :string
    field :amount, :decimal
    field :is_recurring, :boolean, default: false
    field :recurrence_rule, :map
    # Legacy field - kept for backward compatibility during migration
    field :tags, {:array, :string}, default: []

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    has_many :entries, MegaPlanner.Budget.Entry, on_delete: :delete_all
    many_to_many :tag_objects, MegaPlanner.Tags.Tag,
      join_through: "budget_sources_tags",
      join_keys: [budget_source_id: :id, tag_id: :id],
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(source, attrs) do
    source
    |> cast(attrs, [:name, :type, :amount, :tags, :user_id, :household_id])
    |> validate_required([:name, :type, :user_id, :household_id])
    |> validate_inclusion(:type, @types)
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
  end
end
