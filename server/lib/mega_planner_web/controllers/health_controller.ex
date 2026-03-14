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

    # List tables (SQLite version)
    diag = try do
      {:ok, result} = Repo.query("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
      tables = Enum.map(result.rows, fn [name] -> name end)
      diag
      |> Map.put(:tables, tables)
      |> Map.put(:has_tasks_table, "tasks" in tables)
      |> Map.put(:has_text_templates_table, "text_templates" in tables)
    rescue
      e -> Map.put(diag, :tables_error, Exception.message(e))
    end

    # Check tasks table columns (SQLite version)
    diag = try do
      {:ok, result} = Repo.query("PRAGMA table_info(tasks)")
      columns = Enum.map(result.rows, fn [_id, name, type, _notnull, _dflt, _pk] -> %{name: name, type: type} end)
      Map.put(diag, :tasks_columns, columns)
    rescue
      e -> Map.put(diag, :tasks_columns_error, Exception.message(e))
    end

    # Check text_templates table columns (SQLite version)
    diag = try do
      {:ok, result} = Repo.query("PRAGMA table_info(text_templates)")
      columns = Enum.map(result.rows, fn [_id, name, type, _notnull, _dflt, _pk] -> %{name: name, type: type} end)
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

    # Test write permissions
    diag = try do
      # Try to create and delete a dummy table to verify write access
      Repo.query!("CREATE TABLE IF NOT EXISTS _write_test (id INTEGER PRIMARY KEY)")
      Repo.query!("INSERT INTO _write_test (id) VALUES (1)")
      Repo.query!("DELETE FROM _write_test WHERE id = 1")
      Repo.query!("DROP TABLE _write_test")
      Map.put(diag, :write_access, "ok")
    rescue
      e -> Map.put(diag, :write_access, %{error: Exception.message(e)})
    end

    json(conn, diag)
  end
end
