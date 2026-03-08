defmodule MegaPlanner.Repo.Migrations.RepairTripStartTimesV2 do
  use Ecto.Migration

  def up do
    # Repair trip_start times that are set to midnight by using stop's time_arrived.
    # If no valid stop time, use noon (12:00:00) as a fallback.
    #
    # SQLite note: The original migration used PostgreSQL-specific syntax:
    #   - Table aliases in UPDATE (e.g., UPDATE trips t SET ...)
    #   - Type cast syntax (::date, ::text, ::timestamp with time zone, ::time)
    #   - EXTRACT(HOUR FROM ...) function
    # Rewritten using SQLite-compatible strftime() and execute fn -> block:
    execute fn ->
      {:ok, %{rows: trips}} = repo().query(
        """
        SELECT id, trip_start FROM trips
        WHERE trip_start IS NOT NULL
          AND CAST(strftime('%H', trip_start) AS INTEGER) = 0
          AND CAST(strftime('%M', trip_start) AS INTEGER) = 0
          AND CAST(strftime('%S', trip_start) AS INTEGER) = 0
        """,
        []
      )

      Enum.each(trips, fn [trip_id, trip_start] ->
        date_part = String.slice(trip_start, 0, 10)

        {:ok, %{rows: stops}} = repo().query(
          """
          SELECT time_arrived FROM stops
          WHERE trip_id = ?
            AND time_arrived IS NOT NULL
            AND time_arrived != '00:00:00'
            AND time_arrived != '12:00:00'
          ORDER BY position ASC
          LIMIT 1
          """,
          [trip_id]
        )

        time_part = case stops do
          [[time_arrived]] -> time_arrived
          _ -> "12:00:00"
        end

        new_trip_start = "#{date_part} #{time_part}"
        repo().query!(
          "UPDATE trips SET trip_start = ? WHERE id = ?",
          [new_trip_start, trip_id]
        )
      end)
    end
  end

  def down do
    # Cannot reliably reverse this operation
    :ok
  end
end
