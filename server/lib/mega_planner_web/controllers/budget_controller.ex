defmodule MegaPlannerWeb.BudgetController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Budget

  action_fallback MegaPlannerWeb.FallbackController

  alias MegaPlanner.Receipts

  def summary(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    year = params["year"] |> parse_int(Date.utc_today().year)
    month = params["month"] |> parse_int(Date.utc_today().month)

    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    # 1. Regular Entries (exclude purchases)
    regular_entries = Budget.list_entries(user.household_id, [
      start_date: start_date, 
      end_date: end_date, 
      exclude_purchases: true
    ])

    {reg_income, reg_expense} = Enum.reduce(regular_entries, {Decimal.new(0), Decimal.new(0)}, fn entry, {inc, exp} ->
      if entry.type == "income" do
        {Decimal.add(inc, entry.amount), exp}
      else
        {inc, Decimal.add(exp, entry.amount)}
      end
    end)

    # 2. Trips (calculate total with tax)
    trips = Receipts.list_trips(user.household_id, [
      start_date: start_date, 
      end_date: end_date
    ])

    trips_with_purchases = Enum.filter(trips, fn trip -> 
      trip.stops && Enum.any?(trip.stops, fn stop -> stop.purchases && length(stop.purchases) > 0 end)
    end)

    trip_expense = Enum.reduce(trips_with_purchases, Decimal.new(0), fn trip, acc ->
      trip_total = 
        Enum.reduce(trip.stops || [], Decimal.new(0), fn stop, trip_acc ->
          stop_total =
            Enum.reduce(stop.purchases || [], Decimal.new(0), fn purchase, stop_acc ->
              tax = Receipts.calculate_tax(stop.store_id, purchase.total_price, purchase.taxable)
              purchase_total = Decimal.add(purchase.total_price || Decimal.new(0), tax)
              Decimal.add(stop_acc, purchase_total)
            end)
          Decimal.add(trip_acc, stop_total)
        end)
      Decimal.add(acc, trip_total)
    end)

    # 3. Combine
    income = reg_income
    expense = Decimal.add(reg_expense, trip_expense)
    net = Decimal.sub(income, expense)

    savings_rate = if Decimal.gt?(income, 0) do
      net
      |> Decimal.div(income)
      |> Decimal.mult(100)
      |> Decimal.round(2)
    else
      Decimal.new(0)
    end

    summary = %{
      year: year,
      month: month,
      income: income,
      expense: expense,
      net: net,
      savings_rate: savings_rate,
      entry_count: length(regular_entries) + length(trips_with_purchases)
    }

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
