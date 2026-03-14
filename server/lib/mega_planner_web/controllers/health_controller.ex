defmodule MegaPlannerWeb.HealthController do
  use MegaPlannerWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok", timestamp: DateTime.utc_now()})
  end

  def diagnostics(conn, _params) do
    alias MegaPlanner.Repo
    import Ecto.Query

    diag = %{}

    # Check DB connectivity
    diag = try do
      {:ok, result} = Repo.query("SELECT 1")
      Map.put(diag, :db_connected, true)
    rescue
      e -> Map.put(diag, :db_connected, %{error: Exception.message(e)})
    end

    # List tables
    diag = try do
      {:ok, result} = Repo.query("SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename")
      tables = Enum.map(result.rows, fn [name] -> name end)
      diag
      |> Map.put(:tables, tables)
      |> Map.put(:has_tasks_table, "tasks" in tables)
      |> Map.put(:has_text_templates_table, "text_templates" in tables)
    rescue
      e -> Map.put(diag, :tables_error, Exception.message(e))
    end

    # Check tasks table columns
    diag = try do
      {:ok, result} = Repo.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'tasks' ORDER BY ordinal_position")
      columns = Enum.map(result.rows, fn [name, type] -> %{name: name, type: type} end)
      Map.put(diag, :tasks_columns, columns)
    rescue
      e -> Map.put(diag, :tasks_columns_error, Exception.message(e))
    end

    # Check text_templates table columns
    diag = try do
      {:ok, result} = Repo.query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'text_templates' ORDER BY ordinal_position")
      columns = Enum.map(result.rows, fn [name, type] -> %{name: name, type: type} end)
      Map.put(diag, :text_templates_columns, columns)
    rescue
      e -> Map.put(diag, :text_templates_columns_error, Exception.message(e))
    end

    # Check migration status
    diag = try do
      {:ok, result} = Repo.query("SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 10")
      versions = Enum.map(result.rows, fn [v] -> v end)
      Map.put(diag, :latest_migrations, versions)
    rescue
      e -> Map.put(diag, :migrations_error, Exception.message(e))
    end

    json(conn, diag)
  end
end
