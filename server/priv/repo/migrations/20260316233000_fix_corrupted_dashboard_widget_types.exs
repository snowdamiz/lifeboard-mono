defmodule MegaPlanner.Repo.Migrations.FixCorruptedDashboardWidgetTypes do
  use Ecto.Migration

  @corrupted_inventory_widget "696e7665-6e74-6f72-795f-737461747573"
  @valid_inventory_widget "inventory_status"

  def up do
    repair_dashboard_widgets(@corrupted_inventory_widget, @valid_inventory_widget)
  end

  def down, do: :ok

  defp repair_dashboard_widgets(from_value, to_value) do
    execute("""
    UPDATE user_preferences
    SET dashboard_widgets = REPLACE(
      REPLACE(
        dashboard_widgets,
        '"type":"#{from_value}"',
        '"type":"#{to_value}"'
      ),
      '"id":"#{from_value}"',
      '"id":"#{to_value}"'
    )
    WHERE dashboard_widgets LIKE '%#{from_value}%'
    """)
  end
end
