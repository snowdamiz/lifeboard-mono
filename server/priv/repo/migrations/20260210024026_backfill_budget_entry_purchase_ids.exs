defmodule MegaPlanner.Repo.Migrations.BackfillBudgetEntryPurchaseIds do
  use Ecto.Migration

  def up do
    # Budget entries created via receipt upload have purchase_id = NULL
    # even though their corresponding purchase has budget_entry_id set.
    # This backfills the missing link so trip aggregation works in budget views.
    execute """
    UPDATE budget_entries
    SET purchase_id = p.id
    FROM purchases p
    WHERE p.budget_entry_id = budget_entries.id
      AND budget_entries.purchase_id IS NULL
    """
  end

  def down do
    # No-op: we don't want to un-link entries on rollback
    :ok
  end
end
