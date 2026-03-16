defmodule MegaPlanner.Repo.Migrations.NormalizeSqliteBooleanValues do
  use Ecto.Migration

  @boolean_columns [
    {"budget_sources", "is_recurring"},
    {"goal_milestones", "completed"},
    {"habits", "is_start_of_day"},
    {"inventory_items", "is_necessity"},
    {"inventory_items", "taxable"},
    {"notification_preferences", "task_due_enabled"},
    {"notification_preferences", "low_inventory_enabled"},
    {"notification_preferences", "budget_threshold_enabled"},
    {"notification_preferences", "habit_reminder_enabled"},
    {"notification_preferences", "push_enabled"},
    {"notifications", "read"},
    {"purchases", "taxable"},
    {"shopping_list_items", "purchased"},
    {"shopping_lists", "is_auto_generated"},
    {"tasks", "is_recurring"},
    {"task_steps", "completed"},
    {"tax_indicator_meanings", "is_taxable"}
  ]

  def up do
    Enum.each(@boolean_columns, fn {table, column} ->
      normalize_boolean_column(table, column)
    end)
  end

  def down, do: :ok

  defp normalize_boolean_column(table, column) do
    execute("""
    UPDATE #{table}
    SET #{column} = CASE lower(trim(CAST(#{column} AS TEXT)))
      WHEN 'true' THEN 1
      WHEN 't' THEN 1
      WHEN 'false' THEN 0
      WHEN 'f' THEN 0
      ELSE #{column}
    END
    WHERE lower(trim(CAST(#{column} AS TEXT))) IN ('true', 'false', 't', 'f')
    """)
  end
end
