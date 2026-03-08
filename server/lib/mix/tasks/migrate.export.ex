defmodule Mix.Tasks.Migrate.Export do
  use Mix.Task

  @shortdoc "Export all PostgreSQL data to a JSON file for SQLite import"

  @tables ~w[
    brands
    budget_entries
    budget_entries_tags
    budget_sources
    budget_sources_tags
    drivers
    format_corrections
    goal_categories
    goal_milestones
    goal_status_changes
    goals
    goals_tags
    habit_completions
    habit_inventories
    habits
    habits_tags
    household_invitations
    households
    inventory_items
    inventory_items_tags
    inventory_sheets
    inventory_sheets_tags
    milestone_templates
    notebooks
    notebooks_tags
    notification_preferences
    notifications
    page_links
    pages
    pages_tags
    purchases
    purchases_tags
    shopping_list_items
    shopping_lists
    shopping_lists_tags
    stops
    stores
    tags
    task_steps
    task_templates
    tasks
    tasks_tags
    tax_indicator_meanings
    text_templates
    trips
    units
    user_preferences
    users
  ]

  @doc false
  def run(args) do
    Application.ensure_all_started(:mega_planner)

    output_path = List.first(args) || "migration_export.json"

    database_url =
      System.get_env("POSTGRES_URL") ||
        raise """
        POSTGRES_URL is required. Set it before running:
          POSTGRES_URL=ecto://user:pass@host/db mix migrate.export <output_path>

        For production, first run:
          fly proxy 5432:5432 -a mega-planner-api-db
        """

    opts =
      Ecto.Repo.Supervisor.parse_url(database_url)
      |> Keyword.put(:pool_size, 2)
      |> Keyword.put(:timeout, 60_000)

    {:ok, pg} = Postgrex.start_link(opts)

    IO.puts("Exporting #{length(@tables)} tables from PostgreSQL...")

    export_map =
      @tables
      |> Enum.reduce(%{}, fn table, acc ->
        result = Postgrex.query!(pg, ~s(SELECT * FROM "#{table}"), [])
        rows = Enum.map(result.rows, &row_to_map(result.columns, &1))
        IO.puts("  #{table}: #{length(rows)} rows")
        Map.put(acc, table, rows)
      end)

    output = %{
      "exported_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "tables" => export_map
    }

    json = Jason.encode!(output, pretty: true)
    File.write!(output_path, json)

    IO.puts("\nExport complete: #{output_path} (#{map_size(export_map)} tables)")
  end

  defp row_to_map(columns, row) do
    Enum.zip(columns, row)
    |> Enum.map(fn {col, val} -> {col, serialize(val)} end)
    |> Map.new()
  end

  defp serialize(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp serialize(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize(%Date{} = d), do: Date.to_iso8601(d)
  defp serialize(%Time{} = t), do: Time.to_iso8601(t)
  defp serialize(%Decimal{} = d), do: Decimal.to_string(d)
  # 16-byte binary → UUID string (Postgrex returns raw UUID binaries from direct queries)
  defp serialize(<<_::binary-size(16)>> = bytes), do: Ecto.UUID.cast!(bytes)
  # Other non-UTF-8 binary → base64 to avoid Jason encoding errors
  defp serialize(binary) when is_binary(binary) do
    if String.valid?(binary), do: binary, else: Base.encode64(binary)
  end
  defp serialize(list) when is_list(list), do: Enum.map(list, &serialize/1)
  defp serialize(map) when is_map(map), do: Map.new(map, fn {k, v} -> {k, serialize(v)} end)
  defp serialize(v), do: v
end
