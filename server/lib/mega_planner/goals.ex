defmodule MegaPlanner.Goals do
  @moduledoc """
  The Goals context handles goal tracking, milestones, habits, and goal categories.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Goals.{Goal, GoalCategory, GoalStatusChange, Milestone, Habit, HabitCompletion}
  alias MegaPlanner.Tags.Tag

  # ============================================================================
  # Goal Categories
  # ============================================================================

  @doc """
  Returns the list of goal categories for a household.
  """
  def list_goal_categories(household_id) do
    from(c in GoalCategory,
      where: c.household_id == ^household_id,
      preload: [:subcategories],
      order_by: [asc: c.position, asc: c.name]
    )
    |> Repo.all()
  end

  @doc """
  Returns top-level goal categories (no parent) for a household.
  """
  def list_top_level_categories(household_id) do
    from(c in GoalCategory,
      where: c.household_id == ^household_id and is_nil(c.parent_id),
      preload: [:subcategories],
      order_by: [asc: c.position, asc: c.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single goal category.
  """
  def get_goal_category(id) do
    GoalCategory
    |> Repo.get(id)
    |> Repo.preload([:subcategories, :parent])
  end

  @doc """
  Gets a goal category belonging to a household.
  """
  def get_household_goal_category(household_id, category_id) do
    GoalCategory
    |> Repo.get_by(id: category_id, household_id: household_id)
    |> Repo.preload([:subcategories, :parent])
  end

  @doc """
  Creates a goal category.
  """
  def create_goal_category(attrs \\ %{}) do
    %GoalCategory{}
    |> GoalCategory.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, category} -> {:ok, Repo.preload(category, [:subcategories, :parent])}
      error -> error
    end
  end

  @doc """
  Updates a goal category.
  """
  def update_goal_category(%GoalCategory{} = category, attrs) do
    category
    |> GoalCategory.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, category} -> {:ok, Repo.preload(category, [:subcategories, :parent])}
      error -> error
    end
  end

  @doc """
  Deletes a goal category.
  """
  def delete_goal_category(%GoalCategory{} = category) do
    Repo.delete(category)
  end

  # ============================================================================
  # Goals
  # ============================================================================

  @goal_preloads [:milestones, :tags, goal_category: :parent]

  @doc """
  Returns the list of goals for a household.
  """
  def list_goals(household_id, opts \\ []) do
    status = Keyword.get(opts, :status)
    category_id = Keyword.get(opts, :category_id)
    tag_ids = Keyword.get(opts, :tag_ids)

    query =
      from g in Goal,
        where: g.household_id == ^household_id,
        preload: ^@goal_preloads,
        order_by: [asc: g.target_date, desc: g.inserted_at]

    query =
      if status do
        from g in query, where: g.status == ^status
      else
        query
      end

    query =
      if category_id do
        from g in query, where: g.goal_category_id == ^category_id
      else
        query
      end

    query =
      if tag_ids && length(tag_ids) > 0 do
        from g in query,
          join: t in assoc(g, :tags),
          where: t.id in ^tag_ids,
          distinct: true
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets a single goal.
  """
  def get_goal(id) do
    Goal
    |> Repo.get(id)
    |> Repo.preload(@goal_preloads)
  end

  @doc """
  Gets a goal belonging to a household.
  """
  def get_household_goal(household_id, goal_id) do
    Goal
    |> Repo.get_by(id: goal_id, household_id: household_id)
    |> Repo.preload(@goal_preloads)
  end

  @doc """
  Creates a goal.
  """
  def create_goal(attrs \\ %{}) do
    %Goal{}
    |> Goal.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, goal} -> {:ok, Repo.preload(goal, @goal_preloads)}
      error -> error
    end
  end

  @doc """
  Updates a goal. Tracks status changes if status is modified.
  """
  def update_goal(%Goal{} = goal, attrs, opts \\ []) do
    old_status = goal.status
    user_id = Keyword.get(opts, :user_id)

    goal
    |> Goal.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_goal} ->
        # Track status change if status was modified
        new_status = updated_goal.status
        if old_status != new_status do
          record_status_change(goal.id, old_status, new_status, user_id)
        end
        {:ok, Repo.preload(updated_goal, @goal_preloads, force: true)}
      error -> error
    end
  end

  @doc """
  Records a status change for a goal.
  """
  def record_status_change(goal_id, from_status, to_status, user_id \\ nil, notes \\ nil) do
    %GoalStatusChange{}
    |> GoalStatusChange.changeset(%{
      goal_id: goal_id,
      from_status: from_status,
      to_status: to_status,
      user_id: user_id,
      notes: notes
    })
    |> Repo.insert()
  end

  @doc """
  Gets the history of status changes for a goal.
  """
  def get_goal_history(goal_id) do
    from(sc in GoalStatusChange,
      where: sc.goal_id == ^goal_id,
      order_by: [desc: sc.inserted_at],
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc """
  Gets comprehensive goal history including status changes and milestone completions.
  """
  def get_goal_full_history(goal_id) do
    # Get status changes
    status_changes =
      from(sc in GoalStatusChange,
        where: sc.goal_id == ^goal_id,
        preload: [:user],
        select: %{
          type: "status_change",
          id: sc.id,
          from_status: sc.from_status,
          to_status: sc.to_status,
          notes: sc.notes,
          user: sc.user,
          timestamp: sc.inserted_at
        }
      )
      |> Repo.all()

    # Get milestone completions
    milestone_completions =
      from(m in Milestone,
        where: m.goal_id == ^goal_id and not is_nil(m.completed_at),
        select: %{
          type: "milestone_completed",
          id: m.id,
          title: m.title,
          timestamp: m.completed_at
        }
      )
      |> Repo.all()

    # Combine and sort by timestamp
    (status_changes ++ milestone_completions)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
  end

  @doc """
  Updates the tags on a goal.
  """
  def update_goal_tags(%Goal{} = goal, tag_ids) when is_list(tag_ids) do
    tags = Repo.all(from t in Tag, where: t.id in ^tag_ids)

    goal
    |> Repo.preload(:tags)
    |> Goal.tags_changeset(tags)
    |> Repo.update()
    |> case do
      {:ok, goal} -> {:ok, Repo.preload(goal, @goal_preloads, force: true)}
      error -> error
    end
  end

  @doc """
  Deletes a goal.
  """
  def delete_goal(%Goal{} = goal) do
    Repo.delete(goal)
  end

  @doc """
  Updates goal progress based on completed milestones.
  """
  def update_goal_progress(%Goal{} = goal) do
    goal = Repo.preload(goal, :milestones, force: true)

    total = length(goal.milestones)
    completed = Enum.count(goal.milestones, & &1.completed)

    progress = if total > 0, do: round(completed / total * 100), else: 0

    status = cond do
      progress == 100 -> "completed"
      progress > 0 -> "in_progress"
      true -> goal.status
    end

    update_goal(goal, %{progress: progress, status: status})
  end

  # ============================================================================
  # Milestones
  # ============================================================================

  @doc """
  Gets a milestone.
  """
  def get_milestone(id) do
    Repo.get(Milestone, id)
  end

  @doc """
  Gets a milestone belonging to a goal.
  """
  def get_goal_milestone(goal_id, milestone_id) do
    Repo.get_by(Milestone, id: milestone_id, goal_id: goal_id)
  end

  @doc """
  Creates a milestone for a goal.
  """
  def create_milestone(goal_id, attrs) do
    # Get the next position
    position =
      from(m in Milestone,
        where: m.goal_id == ^goal_id,
        select: max(m.position)
      )
      |> Repo.one()
      |> Kernel.||(0)
      |> Kernel.+(1)

    attrs = Map.merge(attrs, %{"goal_id" => goal_id, "position" => position})

    result =
      %Milestone{}
      |> Milestone.changeset(attrs)
      |> Repo.insert()

    # Update goal progress after adding milestone
    case result do
      {:ok, milestone} ->
        goal = get_goal(goal_id)
        update_goal_progress(goal)
        {:ok, milestone}
      error ->
        error
    end
  end

  @doc """
  Updates a milestone.
  """
  def update_milestone(%Milestone{} = milestone, attrs) do
    result =
      milestone
      |> Milestone.changeset(attrs)
      |> Repo.update()

    # Update goal progress if completion status changed
    case result do
      {:ok, updated_milestone} ->
        goal = get_goal(milestone.goal_id)
        update_goal_progress(goal)
        {:ok, updated_milestone}
      error ->
        error
    end
  end

  @doc """
  Toggles milestone completion.
  """
  def toggle_milestone(%Milestone{} = milestone) do
    changeset = if milestone.completed do
      Milestone.uncomplete_changeset(milestone)
    else
      Milestone.complete_changeset(milestone)
    end

    result = Repo.update(changeset)

    case result do
      {:ok, updated_milestone} ->
        goal = get_goal(milestone.goal_id)
        update_goal_progress(goal)
        {:ok, updated_milestone}
      error ->
        error
    end
  end

  @doc """
  Deletes a milestone.
  """
  def delete_milestone(%Milestone{} = milestone) do
    goal_id = milestone.goal_id
    result = Repo.delete(milestone)

    case result do
      {:ok, _} ->
        goal = get_goal(goal_id)
        if goal, do: update_goal_progress(goal)
        result
      error ->
        error
    end
  end

  # ============================================================================
  # Habits
  # ============================================================================

  @doc """
  Returns the list of habits for a household.
  """
  def list_habits(household_id) do
    from(h in Habit,
      where: h.household_id == ^household_id,
      order_by: [desc: h.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single habit.
  """
  def get_habit(id) do
    Repo.get(Habit, id)
  end

  @doc """
  Gets a habit belonging to a household.
  """
  def get_household_habit(household_id, habit_id) do
    Repo.get_by(Habit, id: habit_id, household_id: household_id)
  end

  @doc """
  Creates a habit.
  """
  def create_habit(attrs \\ %{}) do
    %Habit{}
    |> Habit.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a habit.
  """
  def update_habit(%Habit{} = habit, attrs) do
    habit
    |> Habit.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a habit.
  """
  def delete_habit(%Habit{} = habit) do
    Repo.delete(habit)
  end

  @doc """
  Completes a habit for today. Returns error if already completed today.
  """
  def complete_habit(%Habit{} = habit) do
    today = Date.utc_today()
    now = DateTime.utc_now()

    # Check if already completed today
    existing = Repo.get_by(HabitCompletion, habit_id: habit.id, date: today)

    if existing do
      {:error, :already_completed}
    else
      Repo.transaction(fn ->
        # Create completion
        {:ok, completion} =
          %HabitCompletion{}
          |> HabitCompletion.changeset(%{
            habit_id: habit.id,
            date: today,
            completed_at: now
          })
          |> Repo.insert()

        # Update streak
        habit = update_habit_streak(habit)

        {completion, habit}
      end)
    end
  end

  @doc """
  Uncompletes a habit for today.
  """
  def uncomplete_habit(%Habit{} = habit) do
    today = Date.utc_today()

    case Repo.get_by(HabitCompletion, habit_id: habit.id, date: today) do
      nil ->
        {:error, :not_completed}
      completion ->
        Repo.delete(completion)
        # Recalculate streak
        habit = recalculate_habit_streak(habit)
        {:ok, habit}
    end
  end

  @doc """
  Gets habit completions for a date range.
  """
  def get_habit_completions(habit_id, start_date, end_date) do
    from(c in HabitCompletion,
      where: c.habit_id == ^habit_id,
      where: c.date >= ^start_date and c.date <= ^end_date,
      order_by: [desc: c.date]
    )
    |> Repo.all()
  end

  @doc """
  Gets all completions for a household's habits in a date range.
  """
  def get_household_habit_completions(household_id, start_date, end_date) do
    from(c in HabitCompletion,
      join: h in Habit, on: c.habit_id == h.id,
      where: h.household_id == ^household_id,
      where: c.date >= ^start_date and c.date <= ^end_date,
      order_by: [desc: c.date],
      select: c
    )
    |> Repo.all()
  end

  @doc """
  Checks if a habit is completed for a specific date.
  """
  def habit_completed_on?(habit_id, date) do
    Repo.exists?(from c in HabitCompletion,
      where: c.habit_id == ^habit_id and c.date == ^date
    )
  end

  # Private helpers for streak calculation

  defp update_habit_streak(%Habit{} = habit) do
    today = Date.utc_today()
    yesterday = Date.add(today, -1)

    # Check if yesterday was completed (or if this is first completion)
    yesterday_completed = habit_completed_on?(habit.id, yesterday)

    new_streak = if yesterday_completed or habit.streak_count == 0 do
      habit.streak_count + 1
    else
      1  # Reset streak
    end

    longest = max(new_streak, habit.longest_streak)

    {:ok, updated_habit} =
      habit
      |> Habit.streak_changeset(%{
        streak_count: new_streak,
        longest_streak: longest,
        last_completed_at: DateTime.utc_now()
      })
      |> Repo.update()

    updated_habit
  end

  defp recalculate_habit_streak(%Habit{} = habit) do
    today = Date.utc_today()

    # Get recent completions to recalculate streak
    recent_completions =
      from(c in HabitCompletion,
        where: c.habit_id == ^habit.id,
        where: c.date <= ^today,
        order_by: [desc: c.date],
        limit: 365
      )
      |> Repo.all()

    streak = calculate_streak_from_completions(recent_completions, today)

    {:ok, updated_habit} =
      habit
      |> Habit.streak_changeset(%{streak_count: streak})
      |> Repo.update()

    updated_habit
  end

  defp calculate_streak_from_completions(completions, from_date) do
    dates = Enum.map(completions, & &1.date) |> MapSet.new()

    count_consecutive(dates, from_date, 0)
  end

  defp count_consecutive(dates, date, count) do
    if MapSet.member?(dates, date) do
      count_consecutive(dates, Date.add(date, -1), count + 1)
    else
      # Allow one day gap for "yesterday" logic
      yesterday = Date.add(date, -1)
      if MapSet.member?(dates, yesterday) and count == 0 do
        count_consecutive(dates, yesterday, 0)
      else
        count
      end
    end
  end
end
