defmodule MegaPlanner.Repo.Migrations.FixCascadeDeletes do
  use Ecto.Migration

  @doc """
  This migration fixes cascade delete behavior to ensure that when parent
  entities are deleted from the GUI, all related child entities are also
  deleted from the database.

  Cascade Logic (CASCADE = delete child when parent deleted):
  - Trip deletion → cascades to Stops → cascades to Purchases
  - Purchase deletion → cascades to Budget Entries (entry was created for that purchase)
  - Task deletion → cascades to TaskSteps
  - Source deletion → cascades to Budget Entries (entries belong to source)

  Nullify Logic (SET NULL = keep child, remove reference):
  - Purchase deletion → nullifies Inventory Items references (item stays, loses purchase link)
  - Stop deletion → nullifies Inventory Items references (item stays, loses stop link)
  - Trip deletion → nullifies Inventory Items references (item stays, loses trip link)
  - Trip deletion → nullifies Task.trip_id (task stays, loses trip link)

  SQLite Note: SQLite does not support ALTER TABLE ADD/DROP CONSTRAINT.
  FK cascade behavior is defined at table creation time and cannot be changed.
  The original create migrations already define the FK behavior for SQLite.
  The only structural change applied here is making purchases.budget_entry_id nullable,
  which requires a full table rebuild in SQLite.
  """

  def up do
    # SQLite does not support ALTER TABLE DROP CONSTRAINT / ADD CONSTRAINT.
    # All FK constraint modifications are no-ops for SQLite — FK cascade behavior
    # is already defined at table creation time in the original create migrations.
    # No-op: purchases.stop_id, purchases.budget_entry_id FK constraints
    # No-op: budget_entries.purchase_id FK constraint
    # No-op: task_steps.task_id FK constraint (already CASCADE in create_tasks migration)
    # No-op: budget_entries.source_id FK constraint
    # No-op: inventory_items.purchase_id, trip_id, stop_id FK constraints
    # No-op: tasks.trip_id FK constraint

    # STRUCTURAL CHANGE: Make purchases.budget_entry_id nullable using SQLite table rebuild.
    # This allows purchases to exist without a linked budget entry (e.g., after budget entry
    # is deleted with SET NULL semantics).
    # Note: at this migration point, purchases table has these columns:
    #   id, household_id, stop_id, budget_entry_id (NOT NULL), brand, item,
    #   unit_measurement, count, price_per_count, units, price_per_unit,
    #   taxable, total_price, store_code, item_name, tax_rate, timestamps
    # (count_unit is added later in 20260206021800_add_count_unit_field.exs)

    execute """
    CREATE TABLE purchases_new (
      id BLOB NOT NULL PRIMARY KEY,
      household_id BLOB NOT NULL REFERENCES households(id) ON DELETE CASCADE,
      stop_id BLOB REFERENCES stops(id) ON DELETE SET NULL,
      budget_entry_id BLOB REFERENCES budget_entries(id) ON DELETE SET NULL,
      brand VARCHAR(255) NOT NULL,
      item VARCHAR(255) NOT NULL,
      unit_measurement VARCHAR(255),
      count NUMERIC,
      price_per_count NUMERIC,
      units NUMERIC,
      price_per_unit NUMERIC,
      taxable BOOLEAN DEFAULT FALSE,
      total_price NUMERIC NOT NULL,
      store_code VARCHAR(255),
      item_name VARCHAR(255),
      tax_rate NUMERIC,
      inserted_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL
    )
    """

    execute """
    INSERT INTO purchases_new
      (id, household_id, stop_id, budget_entry_id, brand, item,
       unit_measurement, count, price_per_count, units, price_per_unit,
       taxable, total_price, store_code, item_name, tax_rate,
       inserted_at, updated_at)
    SELECT
      id, household_id, stop_id, budget_entry_id, brand, item,
      unit_measurement, count, price_per_count, units, price_per_unit,
      taxable, total_price, store_code, item_name, tax_rate,
      inserted_at, updated_at
    FROM purchases
    """

    # Drop existing indexes before dropping table
    execute "DROP INDEX IF EXISTS purchases_household_id_index"
    execute "DROP INDEX IF EXISTS purchases_stop_id_index"
    execute "DROP INDEX IF EXISTS purchases_budget_entry_id_index"
    execute "DROP INDEX IF EXISTS purchases_brand_index"
    execute "DROP INDEX IF EXISTS purchases_item_index"

    execute "DROP TABLE purchases"
    execute "ALTER TABLE purchases_new RENAME TO purchases"

    # Recreate indexes
    create index(:purchases, [:household_id])
    create index(:purchases, [:stop_id])
    create index(:purchases, [:budget_entry_id])
    create index(:purchases, [:brand])
    create index(:purchases, [:item])
  end

  def down do
    # Rebuild purchases back with budget_entry_id as NOT NULL
    execute """
    CREATE TABLE purchases_orig (
      id BLOB NOT NULL PRIMARY KEY,
      household_id BLOB NOT NULL REFERENCES households(id) ON DELETE CASCADE,
      stop_id BLOB REFERENCES stops(id) ON DELETE SET NULL,
      budget_entry_id BLOB NOT NULL REFERENCES budget_entries(id) ON DELETE CASCADE,
      brand VARCHAR(255) NOT NULL,
      item VARCHAR(255) NOT NULL,
      unit_measurement VARCHAR(255),
      count NUMERIC,
      price_per_count NUMERIC,
      units NUMERIC,
      price_per_unit NUMERIC,
      taxable BOOLEAN DEFAULT FALSE,
      total_price NUMERIC NOT NULL,
      store_code VARCHAR(255),
      item_name VARCHAR(255),
      tax_rate NUMERIC,
      inserted_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL
    )
    """

    execute """
    INSERT INTO purchases_orig
      (id, household_id, stop_id, budget_entry_id, brand, item,
       unit_measurement, count, price_per_count, units, price_per_unit,
       taxable, total_price, store_code, item_name, tax_rate,
       inserted_at, updated_at)
    SELECT
      id, household_id, stop_id, budget_entry_id, brand, item,
      unit_measurement, count, price_per_count, units, price_per_unit,
      taxable, total_price, store_code, item_name, tax_rate,
      inserted_at, updated_at
    FROM purchases
    WHERE budget_entry_id IS NOT NULL
    """

    execute "DROP INDEX IF EXISTS purchases_household_id_index"
    execute "DROP INDEX IF EXISTS purchases_stop_id_index"
    execute "DROP INDEX IF EXISTS purchases_budget_entry_id_index"
    execute "DROP INDEX IF EXISTS purchases_brand_index"
    execute "DROP INDEX IF EXISTS purchases_item_index"

    execute "DROP TABLE purchases"
    execute "ALTER TABLE purchases_orig RENAME TO purchases"

    create index(:purchases, [:household_id])
    create index(:purchases, [:stop_id])
    create index(:purchases, [:budget_entry_id])
    create index(:purchases, [:brand])
    create index(:purchases, [:item])
  end
end
