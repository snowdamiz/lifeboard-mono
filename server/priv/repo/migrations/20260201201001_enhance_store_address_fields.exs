defmodule MegaPlanner.Repo.Migrations.EnhanceStoreAddressFields do
  use Ecto.Migration

  def change do
    alter table(:stores) do
      # Store ID from the receipt (e.g., "Store #1234" -> "1234")
      add :store_id, :string
      
      # Structured address fields
      add :street, :string
      add :city, :string
      add :zip_code, :string
      add :suite, :string
      add :phone, :string
    end

    # Create unique index on household + store_id when store_id is present
    # This allows matching stores by their ID across receipts
    create unique_index(:stores, [:household_id, :store_id], 
      where: "store_id IS NOT NULL",
      name: :stores_household_store_id_unique)
    
    # Update existing unique constraint to include store_id
    # Drop old and create new to include store_id as a fallback match
    drop_if_exists unique_index(:stores, [:name, :address, :household_id], 
      name: :stores_name_address_household_unique)
    
    create unique_index(:stores, [:household_id, :name, :street, :city], 
      name: :stores_household_name_street_city_unique)
  end
end
