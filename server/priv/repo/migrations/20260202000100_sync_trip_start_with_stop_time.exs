defmodule MegaPlanner.Repo.Migrations.SyncTripStartWithStopTime do
  use Ecto.Migration

  def up do
    # Directly update trip_start to use the stop's time_arrived for all trips.
    # This uses a simpler approach that directly concatenates date and time.
    #
    # SQLite note: The original migration used PostgreSQL-specific syntax:
    #   - Type cast syntax (::date::text, ::text, ::timestamp with time zone, ::time)
    # Rewritten using SQLite-compatible strftime() and execute fn -> block:
    execute fn ->
      {:ok, %{rows: trip_ids}} = repo().query(
        """
        SELECT DISTINCT trips.id
        FROM trips
        JOIN stops s ON s.trip_id = trips.id
        WHERE s.time_arrived IS NOT NULL
          AND s.time_arrived NOT IN ('00:00:00', '12:00:00')
        """,
        []
      )

      Enum.each(trip_ids, fn [trip_id] ->
        {:ok, %{rows: trip_rows}} = repo().query(
          "SELECT trip_start FROM trips WHERE id = ?",
          [trip_id]
        )

        {:ok, %{rows: stop_rows}} = repo().query(
          """
          SELECT COALESCE(time_arrived, '12:00:00')
          FROM stops
          WHERE trip_id = ?
          ORDER BY position ASC
          LIMIT 1
          """,
          [trip_id]
        )

        case {trip_rows, stop_rows} do
          {[[trip_start]], [[time_arrived]]} when is_binary(trip_start) ->
            date_part = String.slice(trip_start, 0, 10)
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
    :ok
  end
end
