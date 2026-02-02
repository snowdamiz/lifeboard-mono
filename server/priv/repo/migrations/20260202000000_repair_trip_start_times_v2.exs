defmodule MegaPlanner.Repo.Migrations.RepairTripStartTimesV2 do
  use Ecto.Migration

  def up do
    # Repair trip_start times that are set to midnight by using stop's time_arrived
    # If no valid stop time, use noon (12:00:00) as a fallback
    execute """
    UPDATE trips t
    SET trip_start = (
      SELECT 
        COALESCE(
          (
            SELECT (t.trip_start::date || ' ' || s.time_arrived::text)::timestamp with time zone
            FROM stops s
            WHERE s.trip_id = t.id
              AND s.time_arrived IS NOT NULL
              AND s.time_arrived != '00:00:00'::time
              AND s.time_arrived != '12:00:00'::time
            ORDER BY s.position ASC
            LIMIT 1
          ),
          -- If no valid stop time, use noon as fallback
          (t.trip_start::date || ' 12:00:00')::timestamp with time zone
        )
    )
    WHERE t.trip_start IS NOT NULL
      AND EXTRACT(HOUR FROM t.trip_start) = 0
      AND EXTRACT(MINUTE FROM t.trip_start) = 0
      AND EXTRACT(SECOND FROM t.trip_start) = 0
    """
  end

  def down do
    # Cannot reliably reverse this operation
    :ok
  end
end
