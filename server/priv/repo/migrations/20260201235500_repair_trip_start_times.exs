defmodule MegaPlanner.Repo.Migrations.RepairTripStartTimes do
  use Ecto.Migration

  def up do
    # Repair trip_start times that are set to midnight by using stop's time_arrived
    # This fixes trips that were created before we started including receipt time.
    #
    # SQLite note: This migration used PostgreSQL-specific syntax:
    #   - Table aliases in UPDATE (e.g., UPDATE trips t SET ...)
    #   - Type cast syntax (::date, ::text, ::timestamp with time zone)
    #   - EXTRACT(HOUR FROM ...) function
    # None of these are supported by SQLite.
    #
    # The equivalent fix using SQLite-compatible SQL via execute fn -> block:
    execute fn ->
      {:ok, %{rows: trips}} = repo().query(
        """
        SELECT id, trip_start FROM trips
        WHERE trip_start IS NOT NULL
          AND CAST(strftime('%H', trip_start) AS INTEGER) = 0
          AND CAST(strftime('%M', trip_start) AS INTEGER) = 0
          AND CAST(strftime('%S', trip_start) AS INTEGER) = 0
          AND EXISTS (
            SELECT 1 FROM stops s
            WHERE s.trip_id = trips.id
              AND s.time_arrived IS NOT NULL
              AND s.time_arrived != '00:00:00'
          )
        """,
        []
      )

      Enum.each(trips, fn [trip_id, trip_start] ->
        # Get the date part from trip_start (first 10 chars of ISO datetime)
        date_part = String.slice(trip_start, 0, 10)

        {:ok, %{rows: stops}} = repo().query(
          """
          SELECT time_arrived FROM stops
          WHERE trip_id = ?
            AND time_arrived IS NOT NULL
            AND time_arrived != '00:00:00'
          ORDER BY position ASC
          LIMIT 1
          """,
          [trip_id]
        )

        case stops do
          [[time_arrived]] ->
            new_trip_start = "#{date_part} #{time_arrived}"
            repo().query!(
              "UPDATE trips SET trip_start = ? WHERE id = ?",
              [new_trip_start, trip_id]
            )
          _ ->
            :ok
        end
      end)
    end
  end

  def down do
    # Cannot reliably reverse this operation
    :ok
  end
end
