defmodule MegaPlanner.Search do
  @moduledoc """
  The Search context handles global search across all features.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Calendar.{Task, TaskStep}
  alias MegaPlanner.Inventory.{Sheet, Item}
  alias MegaPlanner.Budget.Source
  alias MegaPlanner.Notes.Page
  alias MegaPlanner.Goals.{Goal, Milestone, Habit}

  @doc """
  Performs a global search across all entities.
  """
  def search(household_id, query) when is_binary(query) and byte_size(query) > 0 do
    search_term = "%#{query}%"

    tasks = search_tasks(household_id, search_term)
    inventory_items = search_inventory(household_id, search_term)
    budget_sources = search_budget(household_id, search_term)
    pages = search_notes(household_id, search_term)
    goals = search_goals(household_id, search_term)
    habits = search_habits(household_id, search_term)

    %{
      tasks: tasks,
      inventory_items: inventory_items,
      budget_sources: budget_sources,
      pages: pages,
      goals: goals,
      habits: habits,
      total: length(tasks) + length(inventory_items) + length(budget_sources) + length(pages) + length(goals) + length(habits)
    }
  end

  def search(_household_id, _query) do
    %{
      tasks: [],
      inventory_items: [],
      budget_sources: [],
      pages: [],
      goals: [],
      habits: [],
      total: 0
    }
  end

  defp search_tasks(household_id, search_term) do
    # First, find tasks matching title/description
    direct_matches = from(t in Task,
      where: t.household_id == ^household_id and
        (ilike(t.title, ^search_term) or ilike(t.description, ^search_term)),
      select: t.id
    )
    |> Repo.all()

    # Also find tasks that have matching step content
    step_matches = from(s in TaskStep,
      join: t in Task, on: s.task_id == t.id,
      where: t.household_id == ^household_id and ilike(s.content, ^search_term),
      select: t.id
    )
    |> Repo.all()

    # Combine and deduplicate task IDs
    all_task_ids = Enum.uniq(direct_matches ++ step_matches)

    # Fetch tasks with steps
    from(t in Task,
      where: t.id in ^all_task_ids,
      limit: 10,
      order_by: [desc: t.updated_at],
      preload: [:steps]
    )
    |> Repo.all()
    |> Enum.map(fn task ->
      # Build description: include step info if steps exist
      step_info = case length(task.steps) do
        0 -> nil
        count ->
          completed = Enum.count(task.steps, & &1.completed)
          "#{completed}/#{count} steps"
      end

      description = [task.description, step_info]
        |> Enum.filter(& &1)
        |> Enum.join(" • ")

      %{
        id: task.id,
        type: "task",
        title: task.title,
        description: if(description == "", do: nil, else: description),
        date: task.date
      }
    end)
  end

  defp search_inventory(household_id, search_term) do
    from(i in Item,
      join: s in Sheet, on: i.sheet_id == s.id,
      where: s.household_id == ^household_id and ilike(i.name, ^search_term),
      limit: 10,
      select: %{id: i.id, name: i.name, sheet_name: s.name, quantity: i.quantity}
    )
    |> Repo.all()
    |> Enum.map(&%{
      id: &1.id,
      type: "inventory_item",
      title: &1.name,
      description: "#{&1.sheet_name} - Qty: #{&1.quantity}"
    })
  end

  defp search_budget(household_id, search_term) do
    from(s in Source,
      where: s.household_id == ^household_id and ilike(s.name, ^search_term),
      limit: 10,
      order_by: [desc: s.updated_at]
    )
    |> Repo.all()
    |> Enum.map(&%{
      id: &1.id,
      type: "budget_source",
      title: &1.name,
      description: "#{&1.type} - $#{&1.amount}"
    })
  end

  defp search_notes(household_id, search_term) do
    from(p in Page,
      join: n in MegaPlanner.Notes.Notebook, on: p.notebook_id == n.id,
      where: n.household_id == ^household_id and
        (ilike(p.title, ^search_term) or ilike(p.content, ^search_term)),
      limit: 10,
      order_by: [desc: p.updated_at]
    )
    |> Repo.all()
    |> Enum.map(&%{
      id: &1.id,
      type: "page",
      title: &1.title,
      description: String.slice(&1.content || "", 0, 100)
    })
  end

  defp search_goals(household_id, search_term) do
    # Find goals matching title/description directly
    direct_matches = from(g in Goal,
      where: g.household_id == ^household_id and
        (ilike(g.title, ^search_term) or
         (not is_nil(g.description) and ilike(g.description, ^search_term)) or
         (not is_nil(g.category) and ilike(g.category, ^search_term))),
      select: g.id
    )
    |> Repo.all()

    # Also find goals that have matching milestone titles
    milestone_matches = from(m in Milestone,
      join: g in Goal, on: m.goal_id == g.id,
      where: g.household_id == ^household_id and ilike(m.title, ^search_term),
      select: g.id
    )
    |> Repo.all()

    # Combine and deduplicate goal IDs
    all_goal_ids = Enum.uniq(direct_matches ++ milestone_matches)

    # Fetch goals with milestones
    from(g in Goal,
      where: g.id in ^all_goal_ids,
      limit: 10,
      order_by: [desc: g.updated_at],
      preload: [:milestones]
    )
    |> Repo.all()
    |> Enum.map(fn goal ->
      # Build description with progress and milestone info
      milestone_info = case length(goal.milestones) do
        0 -> nil
        count ->
          completed = Enum.count(goal.milestones, & &1.completed)
          "#{completed}/#{count} milestones"
      end

      description = [goal.category, "#{goal.progress}% complete", milestone_info]
        |> Enum.filter(& &1)
        |> Enum.join(" • ")

      %{
        id: goal.id,
        type: "goal",
        title: goal.title,
        description: if(description == "", do: goal.description, else: description),
        date: goal.target_date
      }
    end)
  end

  defp search_habits(household_id, search_term) do
    from(h in Habit,
      where: h.household_id == ^household_id and
        (ilike(h.name, ^search_term) or (not is_nil(h.description) and ilike(h.description, ^search_term))),
      limit: 10,
      order_by: [desc: h.updated_at]
    )
    |> Repo.all()
    |> Enum.map(fn habit ->
      streak_info = if habit.streak_count > 0 do
        "🔥 #{habit.streak_count} day streak"
      else
        habit.frequency
      end

      %{
        id: habit.id,
        type: "habit",
        title: habit.name,
        description: streak_info
      }
    end)
  end
end
