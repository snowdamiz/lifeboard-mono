defmodule MegaPlanner.Budget.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ["income", "expense"]

  schema "budget_entries" do
    field :date, :date
    field :amount, :decimal
    field :type, :string
    field :notes, :string

    belongs_to :source, MegaPlanner.Budget.Source
    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :purchase, MegaPlanner.Receipts.Purchase
    many_to_many :tags, MegaPlanner.Tags.Tag, join_through: "budget_entries_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:date, :amount, :type, :notes, :source_id, :user_id, :household_id, :purchase_id])
    |> validate_required([:date, :amount, :type, :user_id, :household_id])
    |> validate_inclusion(:type, @types)
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:source_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
    |> unique_constraint(:purchase_id,
       name: :budget_entries_purchase_unique,
       message: "A budget entry already exists for this purchase")
  end

  def tags_changeset(entry, tags) do
    entry
    |> change()
    |> put_assoc(:tags, tags)
  end
end
