defmodule MegaPlanner.Repo.Migrations.ChangeCorrectedQuantityToDecimal do
  use Ecto.Migration

  def up do
    # SQLite uses dynamic typing — integer columns accept decimal/float values transparently.
    # ALTER COLUMN to change type is not supported by SQLite (ecto_sqlite3 raises ArgumentError).
    # This migration is a no-op for SQLite: the corrected_quantity column already stores
    # decimal values correctly via SQLite's numeric affinity.
    :ok
  end

  def down do
    # No-op for SQLite (see up/0 comment).
    :ok
  end
end
