defmodule MegaPlanner.Repo.Migrations.RepairTripStartTimes do
  use Ecto.Migration

  def up do
    # Repair trip_start times that are set to midnight by using stop's time_arrived
    # This fixes trips that were created before we started including receipt time
    execute """
    UPDATE trips t
    SET trip_start = (
      SELECT 
        CASE 
          WHEN s.time_arrived IS NOT NULL THEN
            (t.trip_start::date || ' ' || s.time_arrived::text)::timestamp with time zone
          ELSE t.trip_start
        END
      FROM stops s
      WHERE s.trip_id = t.id
      ORDER BY s.position ASC
      LIMIT 1
    )
    WHERE t.trip_start IS NOT NULL
      AND EXTRACT(HOUR FROM t.trip_start) = 0
      AND EXTRACT(MINUTE FROM t.trip_start) = 0
      AND EXTRACT(SECOND FROM t.trip_start) = 0
      AND EXISTS (
        SELECT 1 FROM stops s 
        WHERE s.trip_id = t.id 
          AND s.time_arrived IS NOT NULL
          AND s.time_arrived != '00:00:00'
      )
    """
  end

  def down do
    # Cannot reliably reverse this operation
    :ok
  end
end
