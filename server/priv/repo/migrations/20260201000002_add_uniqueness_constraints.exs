defmodule MegaPlanner.Repo.Migrations.AddUniquenessConstraints do
  use Ecto.Migration

  def up do
    # First, clean up any existing duplicates before adding constraints
    # Use window functions since MIN/MAX don't work with UUID types

    # Delete duplicate tasks (keep first by inserted_at)
    execute """
    DELETE FROM tasks WHERE id IN (
      SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY title, date, household_id ORDER BY inserted_at) as rn
        FROM tasks WHERE date IS NOT NULL
      ) sub WHERE rn > 1
    )
    """

    # Delete duplicate trips (keep first by inserted_at)
    execute """
    DELETE FROM trips WHERE id IN (
      SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY trip_start, household_id ORDER BY inserted_at) as rn
        FROM trips WHERE trip_start IS NOT NULL
      ) sub WHERE rn > 1
    )
    """

    # Delete duplicate stops (keep first by inserted_at)
    execute """
    DELETE FROM stops WHERE id IN (
      SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY trip_id, store_id ORDER BY inserted_at) as rn
        FROM stops WHERE store_id IS NOT NULL
      ) sub WHERE rn > 1
    )
    """

    # Delete duplicate purchases (keep first by inserted_at)
    execute """
    DELETE FROM purchases WHERE id IN (
      SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY stop_id, brand, item ORDER BY inserted_at) as rn
        FROM purchases WHERE stop_id IS NOT NULL
      ) sub WHERE rn > 1
    )
    """

    # Delete duplicate stores (keep first by inserted_at)
    execute """
    DELETE FROM stores WHERE id IN (
      SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY name, address, household_id ORDER BY inserted_at) as rn
        FROM stores
      ) sub WHERE rn > 1
    )
    """

    # Delete duplicate budget entries (keep first by inserted_at)
    execute """
    DELETE FROM budget_entries WHERE id IN (
      SELECT id FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY purchase_id ORDER BY inserted_at) as rn
        FROM budget_entries WHERE purchase_id IS NOT NULL
      ) sub WHERE rn > 1
    )
    """

    # Now create the unique indexes
    create unique_index(:tasks, [:title, :date, :household_id],
      where: "date IS NOT NULL",
      name: :tasks_title_date_household_unique)

    create unique_index(:trips, [:trip_start, :household_id],
      where: "trip_start IS NOT NULL",
      name: :trips_start_household_unique)

    create unique_index(:stops, [:trip_id, :store_id],
      where: "store_id IS NOT NULL",
      name: :stops_trip_store_unique)

    create unique_index(:purchases, [:stop_id, :brand, :item],
      where: "stop_id IS NOT NULL",
      name: :purchases_stop_brand_item_unique)

    create unique_index(:stores, [:name, :address, :household_id],
      name: :stores_name_address_household_unique)

    create unique_index(:budget_entries, [:purchase_id],
      where: "purchase_id IS NOT NULL",
      name: :budget_entries_purchase_unique)
  end

  def down do
    drop_if_exists index(:tasks, [:title, :date, :household_id], name: :tasks_title_date_household_unique)
    drop_if_exists index(:trips, [:trip_start, :household_id], name: :trips_start_household_unique)
    drop_if_exists index(:stops, [:trip_id, :store_id], name: :stops_trip_store_unique)
    drop_if_exists index(:purchases, [:stop_id, :brand, :item], name: :purchases_stop_brand_item_unique)
    drop_if_exists index(:stores, [:name, :address, :household_id], name: :stores_name_address_household_unique)
    drop_if_exists index(:budget_entries, [:purchase_id], name: :budget_entries_purchase_unique)
  end
end
