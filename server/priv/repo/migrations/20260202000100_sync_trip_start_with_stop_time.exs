defmodule MegaPlanner.Repo.Migrations.SyncTripStartWithStopTime do
  use Ecto.Migration

  def up do
    # Directly update trip_start to use the stop's time_arrived for all trips
    # This uses a simpler approach that directly concatenates date and time
    execute """
    UPDATE trips 
    SET trip_start = (trip_start::date::text || ' ' || (
      SELECT COALESCE(s.time_arrived::text, '12:00:00')
      FROM stops s 
      WHERE s.trip_id = trips.id 
      ORDER BY s.position ASC 
      LIMIT 1
    ))::timestamp with time zone
    WHERE id IN (
      SELECT DISTINCT t.id 
      FROM trips t
      JOIN stops s ON s.trip_id = t.id
      WHERE s.time_arrived IS NOT NULL
        AND s.time_arrived::text NOT IN ('00:00:00', '12:00:00')
    )
    """
  end

  def down do
    :ok
  end
end
