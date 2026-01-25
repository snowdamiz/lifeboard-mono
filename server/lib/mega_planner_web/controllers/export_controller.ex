defmodule MegaPlannerWeb.ExportController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.{Calendar, Inventory, Budget, Notes, Goals}

  action_fallback MegaPlannerWeb.FallbackController

  @doc """
  Export all household data as JSON.
  """
  def export_all(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    data = %{
      exported_at: DateTime.utc_now(),
      version: "1.0",
      user: %{
        email: user.email,
        name: user.name
      },
      tasks: export_tasks(user.household_id),
      inventory: export_inventory(user.household_id),
      budget: export_budget(user.household_id),
      notes: export_notes(user.household_id),
      goals: export_goals(user.household_id),
      habits: export_habits(user.household_id)
    }

    conn
    |> put_resp_header("content-disposition", "attachment; filename=\"mega-planner-export-#{Date.to_string(Date.utc_today())}.json\"")
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(data, pretty: true))
  end

  @doc """
  Export tasks as CSV.
  """
  def export_tasks_csv(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    tasks = Calendar.list_tasks(user.household_id, [])

    csv_data = [
      ["ID", "Title", "Description", "Date", "Start Time", "Duration (min)", "Priority", "Status", "Type", "Created At"]
      | Enum.map(tasks, fn task ->
        [
          task.id,
          task.title,
          task.description || "",
          task.date || "",
          task.start_time || "",
          task.duration_minutes || "",
          task.priority,
          task.status,
          task.task_type,
          DateTime.to_iso8601(task.inserted_at)
        ]
      end)
    ]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")

    conn
    |> put_resp_header("content-disposition", "attachment; filename=\"tasks-#{Date.to_string(Date.utc_today())}.csv\"")
    |> put_resp_content_type("text/csv")
    |> send_resp(200, csv_data)
  end

  @doc """
  Export budget entries as CSV.
  """
  def export_budget_csv(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    entries = Budget.list_entries(user.household_id, [])

    csv_data = [
      ["ID", "Date", "Amount", "Type", "Notes", "Source", "Created At"]
      | Enum.map(entries, fn entry ->
        source_name = if entry.source, do: entry.source.name, else: ""
        [
          entry.id,
          entry.date,
          entry.amount,
          entry.type,
          entry.notes || "",
          source_name,
          DateTime.to_iso8601(entry.inserted_at)
        ]
      end)
    ]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")

    conn
    |> put_resp_header("content-disposition", "attachment; filename=\"budget-#{Date.to_string(Date.utc_today())}.csv\"")
    |> put_resp_content_type("text/csv")
    |> send_resp(200, csv_data)
  end

  @doc """
  Export inventory as CSV.
  """
  def export_inventory_csv(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    sheets = Inventory.list_sheets(user.household_id)

    # Flatten all items from all sheets (sheets need to be loaded with items)
    all_items = Enum.flat_map(sheets, fn sheet ->
      sheet_with_items = Inventory.get_sheet(sheet.id)
      items = sheet_with_items.items || []
      Enum.map(items, &Map.put(&1, :sheet_name, sheet.name))
    end)

    csv_data = [
      ["ID", "Sheet", "Name", "Quantity", "Min Quantity", "Is Necessity", "Store", "Created At"]
      | Enum.map(all_items, fn item ->
        [
          item.id,
          item.sheet_name,
          item.name,
          item.quantity,
          item.min_quantity,
          item.is_necessity,
          item.store || "",
          DateTime.to_iso8601(item.inserted_at)
        ]
      end)
    ]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")

    conn
    |> put_resp_header("content-disposition", "attachment; filename=\"inventory-#{Date.to_string(Date.utc_today())}.csv\"")
    |> put_resp_content_type("text/csv")
    |> send_resp(200, csv_data)
  end

  # Private helpers

  defp export_tasks(household_id) do
    Calendar.list_tasks(household_id, [])
    |> Enum.map(fn task ->
      %{
        id: task.id,
        title: task.title,
        description: task.description,
        date: task.date,
        start_time: task.start_time,
        duration_minutes: task.duration_minutes,
        priority: task.priority,
        status: task.status,
        is_recurring: task.is_recurring,
        recurrence_rule: task.recurrence_rule,
        task_type: task.task_type,
        steps: Enum.map(task.steps || [], fn step ->
          %{
            content: step.content,
            completed: step.completed,
            position: step.position
          }
        end),
        tags: Enum.map(task.tags || [], fn tag ->
          %{name: tag.name, color: tag.color}
        end),
        inserted_at: task.inserted_at
      }
    end)
  end

  defp export_inventory(household_id) do
    Inventory.list_sheets(household_id)
    |> Enum.map(fn sheet ->
      sheet_with_items = Inventory.get_sheet(sheet.id)
      items = sheet_with_items.items || []
      %{
        name: sheet.name,
        columns: sheet.columns,
        items: Enum.map(items, fn item ->
          %{
            name: item.name,
            quantity: item.quantity,
            min_quantity: item.min_quantity,
            is_necessity: item.is_necessity,
            store: item.store,
            custom_fields: item.custom_fields
          }
        end)
      }
    end)
  end

  defp export_budget(household_id) do
    sources = Budget.list_sources(household_id)
    entries = Budget.list_entries(household_id, [])

    %{
      sources: Enum.map(sources, fn source ->
        %{
          name: source.name,
          type: source.type,
          amount: source.amount,
          tags: source.tags
        }
      end),
      entries: Enum.map(entries, fn entry ->
        %{
          date: entry.date,
          amount: entry.amount,
          type: entry.type,
          notes: entry.notes,
          source_name: if(entry.source, do: entry.source.name, else: nil)
        }
      end)
    }
  end

  defp export_notes(household_id) do
    Notes.list_notebooks(household_id)
    |> Enum.map(fn notebook ->
      pages = Notes.list_pages(notebook.id)
      %{
        name: notebook.name,
        pages: Enum.map(pages, fn page ->
          %{
            title: page.title,
            content: page.content,
            links: Enum.map(page.links || [], fn link ->
              %{
                link_type: link.link_type,
                linked_id: link.linked_id
              }
            end)
          }
        end)
      }
    end)
  end

  defp export_goals(household_id) do
    Goals.list_goals(household_id)
    |> Enum.map(fn goal ->
      %{
        title: goal.title,
        description: goal.description,
        target_date: goal.target_date,
        status: goal.status,
        category: goal.category,
        progress: goal.progress,
        milestones: Enum.map(goal.milestones || [], fn m ->
          %{
            title: m.title,
            completed: m.completed,
            position: m.position
          }
        end)
      }
    end)
  end

  defp export_habits(household_id) do
    Goals.list_habits(household_id)
    |> Enum.map(fn habit ->
      %{
        name: habit.name,
        description: habit.description,
        frequency: habit.frequency,
        days_of_week: habit.days_of_week,
        color: habit.color,
        streak_count: habit.streak_count,
        longest_streak: habit.longest_streak
      }
    end)
  end
end
