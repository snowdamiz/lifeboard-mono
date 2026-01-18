defmodule MegaPlannerWeb.BudgetEntryController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Budget
  alias MegaPlanner.Budget.Entry

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    opts = []
    |> maybe_add_date(:start_date, params["start_date"])
    |> maybe_add_date(:end_date, params["end_date"])
    |> maybe_add_opt(:type, params["type"])
    |> maybe_add_list(:tag_ids, params["tag_ids"])

    entries = Budget.list_entries(user.household_id, opts)
    json(conn, %{data: Enum.map(entries, &entry_to_json/1)})
  end

  def create(conn, %{"entry" => entry_params}) do
    user = Guardian.Plug.current_resource(conn)
    entry_params = entry_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %Entry{} = entry} <- Budget.create_entry(entry_params) do
      conn
      |> put_status(:created)
      |> json(%{data: entry_to_json(entry)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    case Budget.get_household_entry(user.household_id, id) do
      nil -> {:error, :not_found}
      entry -> json(conn, %{data: entry_to_json(entry)})
    end
  end

  def update(conn, %{"id" => id, "entry" => entry_params}) do
    user = Guardian.Plug.current_resource(conn)

    with entry when not is_nil(entry) <- Budget.get_household_entry(user.household_id, id),
         {:ok, %Entry{} = entry} <- Budget.update_entry(entry, entry_params) do
      json(conn, %{data: entry_to_json(entry)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with entry when not is_nil(entry) <- Budget.get_household_entry(user.household_id, id),
         {:ok, %Entry{}} <- Budget.delete_entry(entry) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp maybe_add_date(opts, key, value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> Keyword.put(opts, key, date)
      _ -> opts
    end
  end
  defp maybe_add_date(opts, _key, _value), do: opts

  defp maybe_add_opt(opts, key, value) when is_binary(value) and value != "" do
    Keyword.put(opts, key, value)
  end
  defp maybe_add_opt(opts, _key, _value), do: opts

  defp maybe_add_list(opts, key, value) when is_binary(value) and value != "" do
    list = String.split(value, ",")
    Keyword.put(opts, key, list)
  end
  defp maybe_add_list(opts, key, value) when is_list(value), do: Keyword.put(opts, key, value)
  defp maybe_add_list(opts, _key, _value), do: opts

  defp entry_to_json(entry) do
    %{
      id: entry.id,
      date: entry.date,
      amount: entry.amount,
      type: entry.type,
      notes: entry.notes,
      source_id: entry.source_id,
      source: if(entry.source, do: %{id: entry.source.id, name: entry.source.name}, else: nil),
      tags: Enum.map(entry.tags || [], &tag_to_json/1),
      inserted_at: entry.inserted_at,
      updated_at: entry.updated_at
    }
  end

  defp tag_to_json(tag) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color
    }
  end
end
