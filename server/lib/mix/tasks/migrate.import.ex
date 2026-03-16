defmodule Mix.Tasks.Migrate.Import do
  use Mix.Task

  @shortdoc "Import JSON export file into local SQLite database"

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:mega_planner)

    input_path = List.first(args) || "migration_export.json"

    File.exists?(input_path) ||
      raise "Export file not found: #{input_path}. Run mix migrate.export first."

    IO.puts("Starting import from #{input_path}...")

    data = File.read!(input_path) |> Jason.decode!()
    tables = data["tables"]

    # SQLite ignores PRAGMA foreign_keys when set inside a transaction.
    # Use checkout to hold a single connection, set PRAGMA before BEGIN, then transact.
    MegaPlanner.Repo.checkout(fn ->
      MegaPlanner.Repo.query!("PRAGMA foreign_keys = OFF")

      MegaPlanner.Repo.transaction(
        fn ->
          # Standard tables (no two-pass needed)
          import_table(tables["brands"], "brands")
          import_table(tables["budget_entries_tags"], "budget_entries_tags")
          import_table(tables["budget_sources"], "budget_sources")
          import_table(tables["budget_sources_tags"], "budget_sources_tags")
          import_table(tables["drivers"], "drivers")
          import_table(tables["format_corrections"], "format_corrections")
          import_table(tables["goal_milestones"], "goal_milestones")
          import_table(tables["goal_status_changes"], "goal_status_changes")
          import_table(tables["goals"], "goals")
          import_table(tables["goals_tags"], "goals_tags")
          import_table(tables["habit_completions"], "habit_completions")
          import_table(tables["habit_inventories"], "habit_inventories")
          import_table(tables["habits"], "habits")
          import_table(tables["habits_tags"], "habits_tags")
          import_table(tables["household_invitations"], "household_invitations")
          import_table(tables["households"], "households")
          import_table(tables["inventory_items"], "inventory_items")
          import_table(tables["inventory_items_tags"], "inventory_items_tags")
          import_table(tables["inventory_sheets"], "inventory_sheets")
          import_table(tables["inventory_sheets_tags"], "inventory_sheets_tags")
          import_table(tables["milestone_templates"], "milestone_templates")
          import_table(tables["notebooks"], "notebooks")
          import_table(tables["notebooks_tags"], "notebooks_tags")
          import_table(tables["notification_preferences"], "notification_preferences")
          import_table(tables["notifications"], "notifications")
          import_table(tables["page_links"], "page_links")
          import_table(tables["pages"], "pages")
          import_table(tables["pages_tags"], "pages_tags")
          import_table(tables["purchases_tags"], "purchases_tags")
          import_table(tables["shopping_list_items"], "shopping_list_items")
          import_table(tables["shopping_lists"], "shopping_lists")
          import_table(tables["shopping_lists_tags"], "shopping_lists_tags")
          import_table(tables["stops"], "stops")
          import_table(tables["stores"], "stores")
          import_table(tables["tags"], "tags")
          import_table(tables["task_steps"], "task_steps")
          import_table(tables["task_templates"], "task_templates")
          import_table(tables["tasks_tags"], "tasks_tags")
          import_table(tables["tax_indicator_meanings"], "tax_indicator_meanings")
          import_table(tables["text_templates"], "text_templates")
          import_table(tables["trips"], "trips")
          import_table(tables["units"], "units")
          import_table(tables["user_preferences"], "user_preferences")
          import_table(tables["users"], "users")

          # Two-pass: tasks (self-referential parent_task_id)
          import_tasks_two_pass(tables["tasks"])

          # Two-pass: goal_categories (self-referential parent_id)
          import_goal_categories_two_pass(tables["goal_categories"])

          # Two-pass: purchases <-> budget_entries (circular FK)
          import_purchases_budget_entries_two_pass(tables["purchases"], tables["budget_entries"])
        end,
        timeout: :infinity
      )

      MegaPlanner.Repo.query!("PRAGMA foreign_keys = ON")
    end)

    result = MegaPlanner.Repo.query!("PRAGMA foreign_key_check")

    case result.rows do
      [] ->
        IO.puts("\nPRAGMA foreign_key_check: PASSED — zero violations")
        IO.puts("Import complete.")

      violations ->
        IO.puts("\nPRAGMA foreign_key_check: FAILED — #{length(violations)} violations")

        Enum.each(violations, fn [table, rowid, parent, fkid] ->
          IO.puts("  #{table} rowid=#{rowid} -> #{parent} (fk #{fkid})")
        end)

        raise "Foreign key violations found after import — see above"
    end
  end

  defp atomize_keys(row) do
    Map.new(row, fn {k, v} -> {String.to_atom(k), encode_for_sqlite(v)} end)
  end

  # Maps (JSONB columns) and lists (array columns) must be JSON-encoded for SQLite TEXT storage
  defp encode_for_sqlite(v) when is_map(v), do: Jason.encode!(v)
  defp encode_for_sqlite(v) when is_list(v), do: Jason.encode!(v)
  defp encode_for_sqlite(v) when is_boolean(v), do: if(v, do: 1, else: 0)
  defp encode_for_sqlite(v), do: v

  defp import_table(nil, table_name) do
    IO.puts("  #{table_name}: missing from export (skipping)")
  end

  defp import_table([], table_name) do
    IO.puts("  #{table_name}: 0 rows (skipping)")
  end

  defp import_table(rows, table_name) do
    entries = Enum.map(rows, &atomize_keys/1)
    {count, _} = MegaPlanner.Repo.insert_all(table_name, entries, on_conflict: :nothing)
    IO.puts("  #{table_name}: #{count} rows")
  end

  defp import_tasks_two_pass(nil) do
    IO.puts("  tasks: missing from export (skipping)")
  end

  defp import_tasks_two_pass(tasks) do
    # Pass 1: Insert all tasks with parent_task_id = nil
    rows_without_parent =
      Enum.map(tasks, fn task ->
        task
        |> Map.put("parent_task_id", nil)
        |> atomize_keys()
      end)

    {count, _} = MegaPlanner.Repo.insert_all("tasks", rows_without_parent, on_conflict: :nothing)
    IO.puts("  tasks: #{count} rows (pass 1)")

    # Pass 2: Update parent_task_id where it was non-nil
    tasks_with_parent = Enum.filter(tasks, fn t -> t["parent_task_id"] != nil end)

    Enum.each(tasks_with_parent, fn task ->
      MegaPlanner.Repo.query!(
        "UPDATE tasks SET parent_task_id = ? WHERE id = ?",
        [task["parent_task_id"], task["id"]]
      )
    end)

    if length(tasks_with_parent) > 0 do
      IO.puts("  tasks: #{length(tasks_with_parent)} parent_task_id links restored (pass 2)")
    end
  end

  defp import_goal_categories_two_pass(nil) do
    IO.puts("  goal_categories: missing from export (skipping)")
  end

  defp import_goal_categories_two_pass(goal_categories) do
    # Pass 1: Insert all goal_categories with parent_id = nil
    rows_without_parent =
      Enum.map(goal_categories, fn cat ->
        cat
        |> Map.put("parent_id", nil)
        |> atomize_keys()
      end)

    {count, _} =
      MegaPlanner.Repo.insert_all("goal_categories", rows_without_parent, on_conflict: :nothing)

    IO.puts("  goal_categories: #{count} rows (pass 1)")

    # Pass 2: Update parent_id where it was non-nil
    cats_with_parent = Enum.filter(goal_categories, fn c -> c["parent_id"] != nil end)

    Enum.each(cats_with_parent, fn cat ->
      MegaPlanner.Repo.query!(
        "UPDATE goal_categories SET parent_id = ? WHERE id = ?",
        [cat["parent_id"], cat["id"]]
      )
    end)

    if length(cats_with_parent) > 0 do
      IO.puts("  goal_categories: #{length(cats_with_parent)} parent_id links restored (pass 2)")
    end
  end

  defp import_purchases_budget_entries_two_pass(nil, nil) do
    IO.puts("  purchases: missing from export (skipping)")
    IO.puts("  budget_entries: missing from export (skipping)")
  end

  defp import_purchases_budget_entries_two_pass(purchases, budget_entries) do
    purchases = purchases || []
    budget_entries = budget_entries || []

    # Pass 1: Insert purchases with budget_entry_id = nil
    purchase_rows =
      Enum.map(purchases, fn p ->
        p |> Map.put("budget_entry_id", nil) |> atomize_keys()
      end)

    {p_count, _} =
      MegaPlanner.Repo.insert_all("purchases", purchase_rows, on_conflict: :nothing)

    IO.puts("  purchases: #{p_count} rows (pass 1)")

    # Pass 1: Insert budget_entries with purchase_id = nil
    budget_entry_rows =
      Enum.map(budget_entries, fn be ->
        be |> Map.put("purchase_id", nil) |> atomize_keys()
      end)

    {be_count, _} =
      MegaPlanner.Repo.insert_all("budget_entries", budget_entry_rows, on_conflict: :nothing)

    IO.puts("  budget_entries: #{be_count} rows (pass 1)")

    # Pass 2: Restore purchases.budget_entry_id
    purchases_with_entry = Enum.filter(purchases, &(&1["budget_entry_id"] != nil))

    Enum.each(purchases_with_entry, fn p ->
      MegaPlanner.Repo.query!(
        "UPDATE purchases SET budget_entry_id = ? WHERE id = ?",
        [p["budget_entry_id"], p["id"]]
      )
    end)

    if length(purchases_with_entry) > 0 do
      IO.puts(
        "  purchases: #{length(purchases_with_entry)} budget_entry_id links restored (pass 2)"
      )
    end

    # Pass 2: Restore budget_entries.purchase_id
    budget_entries_with_purchase = Enum.filter(budget_entries, &(&1["purchase_id"] != nil))

    Enum.each(budget_entries_with_purchase, fn be ->
      MegaPlanner.Repo.query!(
        "UPDATE budget_entries SET purchase_id = ? WHERE id = ?",
        [be["purchase_id"], be["id"]]
      )
    end)

    if length(budget_entries_with_purchase) > 0 do
      IO.puts(
        "  budget_entries: #{length(budget_entries_with_purchase)} purchase_id links restored (pass 2)"
      )
    end
  end
end
