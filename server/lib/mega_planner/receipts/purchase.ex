defmodule MegaPlanner.Receipts.Purchase do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "purchases" do
    field :brand, :string
    field :item, :string
    field :unit_measurement, :string
    field :count, :decimal
    field :price_per_count, :decimal
    field :units, :decimal
    field :price_per_unit, :decimal
    field :taxable, :boolean
    field :tax_rate, :decimal
    field :total_price, :decimal
    field :store_code, :string
    field :item_name, :string

    belongs_to :household, MegaPlanner.Households.Household
    belongs_to :stop, MegaPlanner.Receipts.Stop
    belongs_to :budget_entry, MegaPlanner.Budget.Entry
    many_to_many :tags, MegaPlanner.Tags.Tag, join_through: "purchases_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(purchase, attrs) do
    purchase
    |> cast(attrs, [
      :brand, :item, :unit_measurement, :count, :price_per_count,
      :units, :price_per_unit, :taxable, :tax_rate, :total_price, :store_code,
      :item_name, :household_id, :stop_id, :budget_entry_id
    ])
    |> validate_required([:brand, :item, :total_price, :household_id, :budget_entry_id])
    |> validate_number(:count, greater_than_or_equal_to: 0)
    |> validate_number(:price_per_count, greater_than_or_equal_to: 0)
    |> validate_number(:units, greater_than_or_equal_to: 0)
    |> validate_number(:price_per_unit, greater_than_or_equal_to: 0)
    |> validate_number(:total_price, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:household_id)
    |> foreign_key_constraint(:stop_id)
    |> foreign_key_constraint(:budget_entry_id)
    |> unique_constraint([:stop_id, :brand, :item],
       name: :purchases_stop_brand_item_unique,
       message: "This item already exists in this stop")
  end

  def tags_changeset(purchase, tags) do
    purchase
    |> change()
    |> put_assoc(:tags, tags)
  end
end
