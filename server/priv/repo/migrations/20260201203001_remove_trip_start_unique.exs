defmodule MegaPlanner.Repo.Migrations.RemoveTripStartUniqueConstraint do
  use Ecto.Migration

  def change do
    # Remove the unique constraint on trip_start + household_id
    # Multiple trips can validly start at the same time (e.g., when created from UI without specific time)
    drop_if_exists unique_index(:trips, [:trip_start, :household_id], name: :trips_start_household_unique)
  end
end
