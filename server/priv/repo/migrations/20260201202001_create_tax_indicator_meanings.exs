defmodule MegaPlanner.Repo.Migrations.CreateTaxIndicatorMeanings do
  use Ecto.Migration

  def change do
    create table(:tax_indicator_meanings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all), null: false
      
      # Store name to scope meanings per store (different stores use different indicators)
      add :store_name, :string, null: false
      
      # The indicator character (e.g., "N", "X", "T", "A", "F")
      add :indicator, :string, null: false
      
      # What it means
      add :is_taxable, :boolean, null: false
      add :description, :string  # e.g., "Non-taxable food", "State tax 6%"
      add :default_tax_rate, :decimal, precision: 5, scale: 4  # e.g., 0.06 for 6%
      
      timestamps(type: :utc_datetime)
    end

    # Each household can have one meaning per store + indicator combo
    create unique_index(:tax_indicator_meanings, [:household_id, :store_name, :indicator],
      name: :tax_indicator_meanings_unique)
    
    create index(:tax_indicator_meanings, [:household_id, :store_name])
  end
end
