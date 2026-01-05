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

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:date, :amount, :type, :notes, :source_id, :user_id, :household_id])
    |> validate_required([:date, :amount, :type, :user_id, :household_id])
    |> validate_inclusion(:type, @types)
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:source_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
  end
end
