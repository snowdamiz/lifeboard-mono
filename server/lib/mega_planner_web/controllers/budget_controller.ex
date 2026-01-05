defmodule MegaPlannerWeb.BudgetController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Budget

  action_fallback MegaPlannerWeb.FallbackController

  def summary(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    year = params["year"] |> parse_int(Date.utc_today().year)
    month = params["month"] |> parse_int(Date.utc_today().month)

    summary = Budget.get_monthly_summary(user.household_id, year, month)

    json(conn, %{data: summary})
  end

  defp parse_int(nil, default), do: default
  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
  defp parse_int(value, _default) when is_integer(value), do: value
end
