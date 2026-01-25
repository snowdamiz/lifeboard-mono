defmodule MegaPlanner.Budget do
  @moduledoc """
  The Budget context handles income/expense sources and entries.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Budget.{Source, Entry}
  alias MegaPlanner.Tags.Tag

  # Sources

  @doc """
  Returns the list of budget sources for a household.
  """
  def list_sources(household_id) do
    from(s in Source, where: s.household_id == ^household_id, order_by: [asc: s.name], preload: [:tag_objects])
    |> Repo.all()
  end

  @doc """
  Gets a single source.
  """
  def get_source(id) do
    case Repo.get(Source, id) do
      nil -> nil
      source -> Repo.preload(source, :tag_objects)
    end
  end

  @doc """
  Gets a source for a specific household.
  """
  def get_household_source(household_id, id) do
    case Repo.get_by(Source, id: id, household_id: household_id) do
      nil -> nil
      source -> Repo.preload(source, :tag_objects)
    end
  end

  @doc """
  Creates a source with optional tags.
  """
  def create_source(attrs \\ %{}) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids", [])

    result =
      %Source{}
      |> Source.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, source} ->
        source = update_source_tags(source, tag_ids)
        {:ok, Repo.preload(source, :tag_objects, force: true)}
      error ->
        error
    end
  end

  @doc """
  Updates a source with optional tags.
  """
  def update_source(%Source{} = source, attrs) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids")

    result =
      source
      |> Source.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, source} ->
        source = if tag_ids != nil, do: update_source_tags(source, tag_ids), else: source
        {:ok, Repo.preload(source, :tag_objects, force: true)}
      error ->
        error
    end
  end

  defp update_source_tags(source, tag_ids) when is_list(tag_ids) do
    tags = from(t in Tag, where: t.id in ^tag_ids) |> Repo.all()
    source
    |> Repo.preload(:tag_objects)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tag_objects, tags)
    |> Repo.update!()
  end

  defp update_source_tags(source, _), do: source

  @doc """
  Gets an existing expense source for a store name, or creates one if it doesn't exist.
  This is used to automatically create expense sources when purchases are made at stores.
  """
  def get_or_create_source_for_store(household_id, user_id, store_name) when is_binary(store_name) and store_name != "" do
    # Find existing expense source with this store name
    query = from s in Source,
      where: s.household_id == ^household_id and s.name == ^store_name and s.type == "expense",
      limit: 1

    case Repo.one(query) do
      nil ->
        # Create new expense source for this store
        create_source(%{
          "name" => store_name,
          "type" => "expense",
          "amount" => "0",
          "user_id" => user_id,
          "household_id" => household_id
        })
      source ->
        {:ok, Repo.preload(source, :tag_objects)}
    end
  end

  def get_or_create_source_for_store(_household_id, _user_id, _store_name), do: {:ok, nil}

  @doc """
  Deletes a source.
  """
  def delete_source(%Source{} = source) do
    Repo.delete(source)
  end

  # Entries

  @doc """
  Returns the list of budget entries for a household within a date range.
  """
  def list_entries(household_id, opts \\ []) do
    query = from e in Entry,
      where: e.household_id == ^household_id,
      order_by: [asc: e.date],
      preload: [:source, :tags, purchase: [stop: [:store, :purchases]]]

    query
    |> filter_entries_by_date_range(opts)
    |> filter_entries_by_type(opts)
    |> filter_entries_by_tags(opts)
    |> filter_entries_exclude_purchases(opts)
    |> Repo.all()
  end

  defp filter_entries_exclude_purchases(query, opts) do
    if Keyword.get(opts, :exclude_purchases) do
      from e in query, where: is_nil(e.purchase_id)
    else
      query
    end
  end

  defp filter_entries_by_tags(query, opts) do
    case Keyword.get(opts, :tag_ids) do
      nil -> query
      [] -> query
      tag_ids ->
        from e in query,
          join: t in assoc(e, :tags),
          where: t.id in ^tag_ids,
          distinct: true
    end
  end

  defp filter_entries_by_date_range(query, opts) do
    case {Keyword.get(opts, :start_date), Keyword.get(opts, :end_date)} do
      {nil, nil} -> query
      {start_date, nil} -> from e in query, where: e.date >= ^start_date
      {nil, end_date} -> from e in query, where: e.date <= ^end_date
      {start_date, end_date} -> from e in query, where: e.date >= ^start_date and e.date <= ^end_date
    end
  end

  defp filter_entries_by_type(query, opts) do
    case Keyword.get(opts, :type) do
      nil -> query
      type -> from e in query, where: e.type == ^type
    end
  end

  @doc """
  Gets a single entry.
  """
  def get_entry(id) do
    Entry
    |> Repo.get(id)
    |> Repo.preload([:source, :tags])
  end

  @doc """
  Gets an entry for a specific household.
  """
  def get_household_entry(household_id, id) do
    Entry
    |> Repo.get_by(id: id, household_id: household_id)
    |> Repo.preload([:source, :tags])
  end

  @doc """
  Creates an entry with optional tags.
  """
  def create_entry(attrs \\ %{}) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids", [])

    %Entry{}
    |> Entry.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, entry} ->
        entry = update_entry_tags(entry, tag_ids)
        {:ok, Repo.preload(entry, [:source, :tags])}
      error -> error
    end
  end

  @doc """
  Updates an entry with optional tags.
  """
  def update_entry(%Entry{} = entry, attrs) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids")

    entry
    |> Entry.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, entry} ->
        entry = if tag_ids != nil, do: update_entry_tags(entry, tag_ids), else: entry
        {:ok, Repo.preload(entry, [:source, :tags], force: true)}
      error -> error
    end
  end

  defp update_entry_tags(entry, tag_ids) when is_list(tag_ids) do
    tags = from(t in Tag, where: t.id in ^tag_ids) |> Repo.all()
    entry
    |> Repo.preload(:tags)
    |> Entry.tags_changeset(tags)
    |> Repo.update!()
  end

  defp update_entry_tags(entry, _), do: entry

  @doc """
  Deletes an entry.
  """
  def delete_entry(%Entry{} = entry) do
    Repo.delete(entry)
  end

  @doc """
  Calculates budget summary for a given month.
  """
  def get_monthly_summary(household_id, year, month) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    entries = list_entries(household_id, start_date: start_date, end_date: end_date)

    income = entries
      |> Enum.filter(&(&1.type == "income"))
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&2, &1.amount))

    expense = entries
      |> Enum.filter(&(&1.type == "expense"))
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&2, &1.amount))

    net = Decimal.sub(income, expense)

    savings_rate = if Decimal.gt?(income, 0) do
      net
      |> Decimal.div(income)
      |> Decimal.mult(100)
      |> Decimal.round(2)
    else
      Decimal.new(0)
    end

    %{
      year: year,
      month: month,
      income: income,
      expense: expense,
      net: net,
      savings_rate: savings_rate,
      entry_count: length(entries)
    }
  end
end
