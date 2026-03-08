defmodule MegaPlanner.Repo.Migrations.CreateShoppingLists do
  use Ecto.Migration

  def up do
    # Create shopping lists table
    create table(:shopping_lists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :household_id, references(:households, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :nilify_all, type: :binary_id)

      add :name, :string, null: false
      add :is_auto_generated, :boolean, default: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:shopping_lists, [:household_id])
    create unique_index(:shopping_lists, [:household_id, :is_auto_generated],
      where: "is_auto_generated = 1",
      name: :shopping_lists_household_auto_generated_unique)

    # SQLite does not support ALTER COLUMN (to change nullability) or adding FK references
    # via ALTER TABLE ADD COLUMN with a reference to a newly created table.
    # Use the SQLite table-rebuild pattern to:
    #   1. Make inventory_item_id nullable (for manual items without inventory reference)
    #   2. Add shopping_list_id FK column
    #   3. Add name column
    execute """
    CREATE TABLE shopping_list_items_new (
      id BLOB NOT NULL PRIMARY KEY,
      quantity_needed INTEGER DEFAULT 1,
      purchased BOOLEAN DEFAULT FALSE,
      inventory_item_id BLOB REFERENCES inventory_items(id) ON DELETE CASCADE,
      user_id BLOB NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      household_id BLOB REFERENCES households(id) ON DELETE CASCADE,
      shopping_list_id BLOB REFERENCES shopping_lists(id) ON DELETE CASCADE,
      name VARCHAR(255),
      inserted_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL
    )
    """

    execute """
    INSERT INTO shopping_list_items_new
      (id, quantity_needed, purchased, inventory_item_id, user_id, household_id, inserted_at, updated_at)
    SELECT id, quantity_needed, purchased, inventory_item_id, user_id, household_id, inserted_at, updated_at
    FROM shopping_list_items
    """

    # Drop old indexes (custom indexes must be dropped before renaming)
    execute "DROP INDEX IF EXISTS shopping_list_items_user_id_inventory_item_id_index"
    execute "DROP INDEX IF EXISTS shopping_list_items_user_id_index"
    execute "DROP INDEX IF EXISTS shopping_list_items_inventory_item_id_index"

    execute "DROP TABLE shopping_list_items"
    execute "ALTER TABLE shopping_list_items_new RENAME TO shopping_list_items"

    # Recreate indexes
    create index(:shopping_list_items, [:user_id])
    create index(:shopping_list_items, [:inventory_item_id])

    execute """
    CREATE UNIQUE INDEX shopping_list_items_user_id_inventory_item_id_index
    ON shopping_list_items (user_id, inventory_item_id)
    WHERE purchased = 0
    """

    create index(:shopping_list_items, [:shopping_list_id])
  end

  def down do
    # Drop shopping list indexes
    execute "DROP INDEX IF EXISTS shopping_list_items_user_id_inventory_item_id_index"
    drop_if_exists index(:shopping_list_items, [:shopping_list_id])
    drop_if_exists index(:shopping_list_items, [:inventory_item_id])
    drop_if_exists index(:shopping_list_items, [:user_id])

    # Rebuild shopping_list_items back to original structure (inventory_item_id NOT NULL, keep household_id from migration 13)
    execute """
    CREATE TABLE shopping_list_items_orig (
      id BLOB NOT NULL PRIMARY KEY,
      quantity_needed INTEGER DEFAULT 1,
      purchased BOOLEAN DEFAULT FALSE,
      inventory_item_id BLOB NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
      user_id BLOB NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      household_id BLOB REFERENCES households(id) ON DELETE CASCADE,
      inserted_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL
    )
    """

    execute """
    INSERT INTO shopping_list_items_orig
      (id, quantity_needed, purchased, inventory_item_id, user_id, household_id, inserted_at, updated_at)
    SELECT id, quantity_needed, purchased, inventory_item_id, user_id, household_id, inserted_at, updated_at
    FROM shopping_list_items
    WHERE inventory_item_id IS NOT NULL
    """

    execute "DROP TABLE shopping_list_items"
    execute "ALTER TABLE shopping_list_items_orig RENAME TO shopping_list_items"

    create index(:shopping_list_items, [:user_id])
    create index(:shopping_list_items, [:inventory_item_id])

    execute """
    CREATE UNIQUE INDEX shopping_list_items_user_id_inventory_item_id_index
    ON shopping_list_items (user_id, inventory_item_id)
    WHERE purchased = 0
    """

    drop_if_exists unique_index(:shopping_lists, [:household_id, :is_auto_generated],
      name: :shopping_lists_household_auto_generated_unique)
    drop_if_exists index(:shopping_lists, [:household_id])
    drop table(:shopping_lists)
  end
end
