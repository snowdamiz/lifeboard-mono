defmodule MegaPlanner.Tags do
  @moduledoc """
  The Tags context for managing tags across all features.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Tags.Tag

  @doc """
  Returns the list of tags for a household.
  """
  def list_tags(household_id) do
    from(t in Tag, where: t.household_id == ^household_id, order_by: [asc: t.name])
    |> Repo.all()
  end

  @doc """
  Gets a single tag.
  """
  def get_tag(id) do
    Repo.get(Tag, id)
  end

  @doc """
  Gets a tag for a specific household.
  """
  def get_household_tag(household_id, id) do
    Repo.get_by(Tag, id: id, household_id: household_id)
  end

  @doc """
  Creates a tag.
  """
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tag.
  """
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tag.
  """
  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  @doc """
  Gets a tag with all associated items preloaded.
  """
  def get_tag_with_items(household_id, tag_id) do
    case get_household_tag(household_id, tag_id) do
      nil -> nil
      tag -> Repo.preload(tag, [:tasks, :goals, :pages, :habits, :inventory_items, :budget_sources])
    end
  end

  @doc """
  Returns usage statistics for all tags in a household.
  Shows count of items tagged with each tag.
  """
  def get_tags_with_usage(household_id) do
    tags = list_tags(household_id)

    Enum.map(tags, fn tag ->
    tag = Repo.preload(tag, [:tasks, :goals, :pages, :habits, :inventory_items, :budget_sources, :inventory_sheets, :shopping_lists, :budget_entries, :notebooks])

      usage = %{
        tasks: length(tag.tasks),
        goals: length(tag.goals),
        pages: length(tag.pages),
        habits: length(tag.habits),
        inventory_items: length(tag.inventory_items),
        budget_sources: length(tag.budget_sources),
        inventory_sheets: length(tag.inventory_sheets),
        shopping_lists: length(tag.shopping_lists),
        budget_entries: length(tag.budget_entries),
        notebooks: length(tag.notebooks)
      }

      total = Enum.sum(Map.values(usage))

      %{
        id: tag.id,
        name: tag.name,
        color: tag.color,
        usage: usage,
        total_usage: total
      }
    end)
  end

  @doc """
  Searches for all items with the specified tags.
  Returns items categorized by type.
  """
  def search_by_tags(household_id, tag_ids, opts \\ []) when is_list(tag_ids) do
    mode = Keyword.get(opts, :mode, :any) # :any = OR, :all = AND

    tags = from(t in Tag, where: t.household_id == ^household_id and t.id in ^tag_ids)
           |> Repo.all()
           |> Repo.preload([:tasks, :goals, :pages, :habits, :inventory_items, :budget_sources, :inventory_sheets, :shopping_lists, :budget_entries, :notebooks])

    if mode == :all do
      # All tags mode - find items that have ALL specified tags
      search_by_tags_all(tags, tag_ids)
    else
      # Any tags mode - find items that have ANY of the specified tags
      search_by_tags_any(tags)
    end
  end

  defp search_by_tags_any(tags) do
    # Combine all items from all tags, deduplicate by id
    %{
      tasks: tags |> Enum.flat_map(& &1.tasks) |> Enum.uniq_by(& &1.id),
      goals: tags |> Enum.flat_map(& &1.goals) |> Enum.uniq_by(& &1.id),
      pages: tags |> Enum.flat_map(& &1.pages) |> Enum.uniq_by(& &1.id),
      habits: tags |> Enum.flat_map(& &1.habits) |> Enum.uniq_by(& &1.id),
      inventory_items: tags |> Enum.flat_map(& &1.inventory_items) |> Enum.uniq_by(& &1.id),
      budget_sources: tags |> Enum.flat_map(& &1.budget_sources) |> Enum.uniq_by(& &1.id),
      inventory_sheets: tags |> Enum.flat_map(& &1.inventory_sheets) |> Enum.uniq_by(& &1.id),
      shopping_lists: tags |> Enum.flat_map(& &1.shopping_lists) |> Enum.uniq_by(& &1.id),
      budget_entries: tags |> Enum.flat_map(& &1.budget_entries) |> Enum.uniq_by(& &1.id),
      notebooks: tags |> Enum.flat_map(& &1.notebooks) |> Enum.uniq_by(& &1.id)
    }
  end

  defp search_by_tags_all(tags, tag_ids) do
    tag_count = length(tag_ids)

    # For AND mode, find items that appear in ALL tags
    find_items_with_all_tags = fn items_list ->
      items_list
      |> List.flatten()
      |> Enum.group_by(& &1.id)
      |> Enum.filter(fn {_id, occurrences} -> length(occurrences) >= tag_count end)
      |> Enum.map(fn {_id, [item | _]} -> item end)
    end

    %{
      tasks: find_items_with_all_tags.(Enum.map(tags, & &1.tasks)),
      goals: find_items_with_all_tags.(Enum.map(tags, & &1.goals)),
      pages: find_items_with_all_tags.(Enum.map(tags, & &1.pages)),
      habits: find_items_with_all_tags.(Enum.map(tags, & &1.habits)),
      inventory_items: find_items_with_all_tags.(Enum.map(tags, & &1.inventory_items)),
      budget_sources: find_items_with_all_tags.(Enum.map(tags, & &1.budget_sources)),
      inventory_sheets: find_items_with_all_tags.(Enum.map(tags, & &1.inventory_sheets)),
      shopping_lists: find_items_with_all_tags.(Enum.map(tags, & &1.shopping_lists)),
      budget_entries: find_items_with_all_tags.(Enum.map(tags, & &1.budget_entries)),
      notebooks: find_items_with_all_tags.(Enum.map(tags, & &1.notebooks))
    }
  end

  @doc """
  Creates tasks from tagged items (e.g., goals, habits) for easy todo list creation.
  """
  def create_tasks_from_tags(household_id, user_id, tag_ids, opts \\ []) do
    include_types = Keyword.get(opts, :include_types, [:goals, :habits])
    date = Keyword.get(opts, :date, Date.utc_today())

    items = search_by_tags(household_id, tag_ids)

    tasks_to_create = []

    tasks_to_create = if :goals in include_types do
      goal_tasks = Enum.map(items.goals, fn goal ->
        %{
          "title" => goal.title,
          "description" => goal.description,
          "date" => date,
          "status" => "not_started",
          "task_type" => "todo",
          "user_id" => user_id,
          "household_id" => household_id,
          "tag_ids" => tag_ids
        }
      end)
      tasks_to_create ++ goal_tasks
    else
      tasks_to_create
    end

    tasks_to_create = if :habits in include_types do
      habit_tasks = Enum.map(items.habits, fn habit ->
        %{
          "title" => habit.name,
          "description" => habit.description,
          "date" => date,
          "status" => "not_started",
          "task_type" => "todo",
          "user_id" => user_id,
          "household_id" => household_id,
          "tag_ids" => tag_ids
        }
      end)
      tasks_to_create ++ habit_tasks
    else
      tasks_to_create
    end

    # Create tasks
    alias MegaPlanner.Calendar

    created_tasks = Enum.map(tasks_to_create, fn task_attrs ->
      case Calendar.create_task(task_attrs) do
        {:ok, task} -> task
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(& &1)

    {:ok, created_tasks}
  end
end
