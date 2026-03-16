defmodule Mix.Tasks.Migrate.Verify do
  use Mix.Task

  @shortdoc "Compare record counts between PostgreSQL and SQLite for all tables"

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:mega_planner)

    database_url =
      System.get_env("POSTGRES_URL") ||
        raise """
        POSTGRES_URL is required for verify.
        Run: fly proxy 5432:5432 -a mega-planner-api-db first, then:
          POSTGRES_URL=ecto://user:pass@localhost:5432/mega_planner_api mix migrate.verify
        """

    opts =
      Ecto.Repo.Supervisor.parse_url(database_url)
      |> Keyword.put(:pool_size, 2)
      |> Keyword.put(:timeout, 60_000)

    {:ok, pg} = Postgrex.start_link(opts)

    IO.puts("Fetching table list from SQLite...")

    result =
      MegaPlanner.Repo.query!(
        "SELECT name FROM sqlite_master WHERE type='table' AND name != 'schema_migrations' ORDER BY name"
      )

    tables = result.rows |> List.flatten()

    IO.puts("Comparing #{length(tables)} tables between PostgreSQL and SQLite...\n")

    discrepancies =
      Enum.reduce(tables, [], fn table, acc ->
        try do
          pg_count =
            Postgrex.query!(pg, ~s[SELECT COUNT(*) FROM "#{table}"], [])
            |> then(&(&1.rows |> hd() |> hd()))

          sqlite_count =
            MegaPlanner.Repo.query!(~s[SELECT COUNT(*) FROM "#{table}"])
            |> then(&(&1.rows |> hd() |> hd()))

          if pg_count != sqlite_count do
            IO.puts("MISMATCH #{table}: pg=#{pg_count} sqlite=#{sqlite_count}")
            [table | acc]
          else
            IO.puts("OK      #{table}: #{pg_count}")
            acc
          end
        rescue
          e in Postgrex.Error ->
            IO.puts("WARN    #{table}: PostgreSQL error — #{Exception.message(e)}")
            [table | acc]

          e in Ecto.QueryError ->
            IO.puts("WARN    #{table}: SQLite error — #{Exception.message(e)}")
            [table | acc]

          e ->
            IO.puts("WARN    #{table}: unexpected error — #{Exception.message(e)}")
            [table | acc]
        end
      end)

    IO.puts("")

    if discrepancies == [] do
      IO.puts("VERIFY: PASSED — all #{length(tables)} tables match")
    else
      IO.puts("VERIFY: FAILED — #{length(discrepancies)} tables with mismatches")
      exit({:shutdown, 1})
    end
  end
end
