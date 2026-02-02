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
  """

  def up do
    # === TRIP CASCADE CHAIN ===
    # Trip → Stops: already cascade in original migration
    
    # Stops → Purchases: should cascade delete when stop is deleted
    execute "ALTER TABLE purchases DROP CONSTRAINT IF EXISTS purchases_stop_id_fkey"
    execute """
    ALTER TABLE purchases
    ADD CONSTRAINT purchases_stop_id_fkey
    FOREIGN KEY (stop_id) REFERENCES stops(id) ON DELETE CASCADE
    """

    # === PURCHASE CASCADE ===
    # Make budget_entry_id in purchases nullable
    execute "ALTER TABLE purchases DROP CONSTRAINT IF EXISTS purchases_budget_entry_id_fkey"
    execute """
    ALTER TABLE purchases
    ADD CONSTRAINT purchases_budget_entry_id_fkey
    FOREIGN KEY (budget_entry_id) REFERENCES budget_entries(id) ON DELETE SET NULL
    """
    alter table(:purchases) do
      modify :budget_entry_id, :binary_id, null: true
    end

    # Budget entries have purchase_id - when purchase deleted, delete the entry
    execute "ALTER TABLE budget_entries DROP CONSTRAINT IF EXISTS budget_entries_purchase_id_fkey"
    execute """
    ALTER TABLE budget_entries
    ADD CONSTRAINT budget_entries_purchase_id_fkey
    FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE CASCADE
    """

    # === TASK CASCADE ===
    # Task steps should be deleted when task is deleted
    execute "ALTER TABLE task_steps DROP CONSTRAINT IF EXISTS task_steps_task_id_fkey"
    execute """
    ALTER TABLE task_steps
    ADD CONSTRAINT task_steps_task_id_fkey
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
    """

    # === SOURCE CASCADE ===
    # Budget entries should be deleted when source is deleted
    execute "ALTER TABLE budget_entries DROP CONSTRAINT IF EXISTS budget_entries_source_id_fkey"
    execute """
    ALTER TABLE budget_entries
    ADD CONSTRAINT budget_entries_source_id_fkey
    FOREIGN KEY (source_id) REFERENCES budget_sources(id) ON DELETE CASCADE
    """

    # === INVENTORY ITEMS NULLIFY ===
    # Inventory items should keep the item but lose the reference
    execute "ALTER TABLE inventory_items DROP CONSTRAINT IF EXISTS inventory_items_purchase_id_fkey"
    execute """
    ALTER TABLE inventory_items
    ADD CONSTRAINT inventory_items_purchase_id_fkey
    FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE SET NULL
    """

    execute "ALTER TABLE inventory_items DROP CONSTRAINT IF EXISTS inventory_items_trip_id_fkey"
    execute """
    ALTER TABLE inventory_items
    ADD CONSTRAINT inventory_items_trip_id_fkey
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE SET NULL
    """

    execute "ALTER TABLE inventory_items DROP CONSTRAINT IF EXISTS inventory_items_stop_id_fkey"
    execute """
    ALTER TABLE inventory_items
    ADD CONSTRAINT inventory_items_stop_id_fkey
    FOREIGN KEY (stop_id) REFERENCES stops(id) ON DELETE SET NULL
    """

    # === TASKS NULLIFY ===
    # Tasks should keep the task but lose the trip reference when trip is deleted
    execute "ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_trip_id_fkey"
    execute """
    ALTER TABLE tasks
    ADD CONSTRAINT tasks_trip_id_fkey
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE SET NULL
    """
  end

  def down do
    # Revert purchases.stop_id to nilify
    execute "ALTER TABLE purchases DROP CONSTRAINT IF EXISTS purchases_stop_id_fkey"
    execute """
    ALTER TABLE purchases
    ADD CONSTRAINT purchases_stop_id_fkey
    FOREIGN KEY (stop_id) REFERENCES stops(id) ON DELETE SET NULL
    """

    # Revert purchases.budget_entry_id
    execute "ALTER TABLE purchases DROP CONSTRAINT IF EXISTS purchases_budget_entry_id_fkey"
    execute """
    ALTER TABLE purchases
    ADD CONSTRAINT purchases_budget_entry_id_fkey
    FOREIGN KEY (budget_entry_id) REFERENCES budget_entries(id) ON DELETE CASCADE
    """

    # Revert budget_entries.purchase_id
    execute "ALTER TABLE budget_entries DROP CONSTRAINT IF EXISTS budget_entries_purchase_id_fkey"
    execute """
    ALTER TABLE budget_entries
    ADD CONSTRAINT budget_entries_purchase_id_fkey
    FOREIGN KEY (purchase_id) REFERENCES purchases(id)
    """

    # Revert task_steps
    execute "ALTER TABLE task_steps DROP CONSTRAINT IF EXISTS task_steps_task_id_fkey"
    execute """
    ALTER TABLE task_steps
    ADD CONSTRAINT task_steps_task_id_fkey
    FOREIGN KEY (task_id) REFERENCES tasks(id)
    """

    # Revert budget_entries.source_id
    execute "ALTER TABLE budget_entries DROP CONSTRAINT IF EXISTS budget_entries_source_id_fkey"
    execute """
    ALTER TABLE budget_entries
    ADD CONSTRAINT budget_entries_source_id_fkey
    FOREIGN KEY (source_id) REFERENCES budget_sources(id) ON DELETE SET NULL
    """

    # Revert inventory_items to nothing (original behavior)
    execute "ALTER TABLE inventory_items DROP CONSTRAINT IF EXISTS inventory_items_purchase_id_fkey"
    execute """
    ALTER TABLE inventory_items
    ADD CONSTRAINT inventory_items_purchase_id_fkey
    FOREIGN KEY (purchase_id) REFERENCES purchases(id)
    """

    execute "ALTER TABLE inventory_items DROP CONSTRAINT IF EXISTS inventory_items_trip_id_fkey"
    execute """
    ALTER TABLE inventory_items
    ADD CONSTRAINT inventory_items_trip_id_fkey
    FOREIGN KEY (trip_id) REFERENCES trips(id)
    """

    execute "ALTER TABLE inventory_items DROP CONSTRAINT IF EXISTS inventory_items_stop_id_fkey"
    execute """
    ALTER TABLE inventory_items
    ADD CONSTRAINT inventory_items_stop_id_fkey
    FOREIGN KEY (stop_id) REFERENCES stops(id)
    """

    # Revert tasks.trip_id
    execute "ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_trip_id_fkey"
    execute """
    ALTER TABLE tasks
    ADD CONSTRAINT tasks_trip_id_fkey
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE SET NULL
    """
  end
end
