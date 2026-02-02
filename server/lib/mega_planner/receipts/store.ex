defmodule MegaPlanner.Receipts.Store do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stores" do
    field :name, :string
    # Legacy full address field (kept for backwards compatibility)
    field :address, :string
    # Structured address fields
    field :street, :string
    field :city, :string
    field :state, :string
    field :zip_code, :string
    field :suite, :string
    field :phone, :string
    # Store ID from the receipt (e.g., "Store #1234" -> "1234")
    field :store_id, :string
    # Legacy store_code field (item-level, different from store_id)
    field :store_code, :string
    field :tax_rate, :decimal
    field :image_url, :string

    belongs_to :household, MegaPlanner.Households.Household
    has_many :stops, MegaPlanner.Receipts.Stop

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(store, attrs) do
    store
    |> cast(attrs, [
      :name, :address, :street, :city, :state, :zip_code, :suite, :phone,
      :store_id, :store_code, :tax_rate, :image_url, :household_id
    ])
    |> validate_required([:name, :household_id])
    |> build_full_address()
    |> foreign_key_constraint(:household_id)
    # Primary unique constraint: household + store_id (when store_id exists)
    |> unique_constraint([:household_id, :store_id],
       name: :stores_household_store_id_unique,
       message: "A store with this ID already exists")
    # Fallback unique constraint: household + name + street + city
    |> unique_constraint([:household_id, :name, :street, :city],
       name: :stores_household_name_street_city_unique,
       message: "A store with this name and address already exists")
  end

  # Build full address from components if not already set
  defp build_full_address(changeset) do
    if get_field(changeset, :address) do
      changeset
    else
      street = get_change(changeset, :street) || get_field(changeset, :street)
      city = get_change(changeset, :city) || get_field(changeset, :city)
      state = get_change(changeset, :state) || get_field(changeset, :state)
      zip = get_change(changeset, :zip_code) || get_field(changeset, :zip_code)
      suite = get_change(changeset, :suite) || get_field(changeset, :suite)
      
      address = build_address_string(street, suite, city, state, zip)
      if address && address != "", do: put_change(changeset, :address, address), else: changeset
    end
  end

  defp build_address_string(nil, _, _, _, _), do: nil
  defp build_address_string(street, suite, city, state, zip) do
    street_part = if suite && suite != "", do: "#{street} #{suite}", else: street
    
    # Build address as: Street, City, State, ZIP (all comma-separated)
    [street_part, city, state, zip]
    |> Enum.reject(&(is_nil(&1) || &1 == ""))
    |> Enum.join(", ")
  end
end

