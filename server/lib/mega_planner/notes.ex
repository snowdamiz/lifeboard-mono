defmodule MegaPlanner.Notes do
  @moduledoc """
  The Notes context handles notebooks, pages, and links.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Notes.{Notebook, Page, PageLink}
  alias MegaPlanner.Tags.Tag

  @page_preloads [:links, :tags]

  # Notebooks

  @doc """
  Returns the list of notebooks for a household.
  """
  def list_notebooks(household_id) do
    from(n in Notebook,
      where: n.household_id == ^household_id,
      order_by: [asc: n.name],
      preload: [:tags]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single notebook.
  """
  def get_notebook(id) do
    Notebook
    |> Repo.get(id)
    |> Repo.preload(:tags)
  end

  @doc """
  Gets a notebook for a specific household.
  """
  def get_household_notebook(household_id, id) do
    Notebook
    |> Repo.get_by(id: id, household_id: household_id)
    |> Repo.preload(:tags)
  end

  @doc """
  Creates a notebook with optional tags.
  """
  def create_notebook(attrs \\ %{}) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids", [])

    %Notebook{}
    |> Notebook.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, notebook} ->
        notebook = update_notebook_tags(notebook, tag_ids)
        {:ok, Repo.preload(notebook, :tags)}
      error -> error
    end
  end

  @doc """
  Updates a notebook with optional tags.
  """
  def update_notebook(%Notebook{} = notebook, attrs) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids")

    notebook
    |> Notebook.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, notebook} ->
        notebook = if tag_ids != nil, do: update_notebook_tags(notebook, tag_ids), else: notebook
        {:ok, Repo.preload(notebook, :tags, force: true)}
      error -> error
    end
  end

  defp update_notebook_tags(notebook, tag_ids) when is_list(tag_ids) do
    tags = from(t in Tag, where: t.id in ^tag_ids) |> Repo.all()
    notebook
    |> Repo.preload(:tags)
    |> Notebook.tags_changeset(tags)
    |> Repo.update!()
  end

  defp update_notebook_tags(notebook, _), do: notebook

  @doc """
  Deletes a notebook.
  """
  def delete_notebook(%Notebook{} = notebook) do
    Repo.delete(notebook)
  end

  # Pages

  @doc """
  Returns the list of pages for a notebook.
  """
  def list_pages(notebook_id, opts \\ []) do
    tag_ids = Keyword.get(opts, :tag_ids)

    query = from(p in Page,
      where: p.notebook_id == ^notebook_id,
      order_by: [desc: p.updated_at]
    )

    query =
      if tag_ids && length(tag_ids) > 0 do
        from p in query,
          join: t in assoc(p, :tags),
          where: t.id in ^tag_ids,
          distinct: true
      else
        query
      end

    query
    |> Repo.all()
    |> Repo.preload(@page_preloads)
  end

  @doc """
  Gets a single page.
  """
  def get_page(id) do
    Page
    |> Repo.get(id)
    |> Repo.preload(@page_preloads)
  end

  @doc """
  Gets a page that belongs to a notebook in the household.
  """
  def get_household_page(household_id, id) do
    from(p in Page,
      join: n in Notebook, on: p.notebook_id == n.id,
      where: p.id == ^id and n.household_id == ^household_id,
      preload: ^@page_preloads
    )
    |> Repo.one()
  end

  @doc """
  Creates a page.
  """
  def create_page(attrs \\ %{}) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids", [])

    result =
      %Page{}
      |> Page.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, page} ->
        page = if tag_ids && length(tag_ids) > 0 do
          update_page_tags_internal(page, tag_ids)
        else
          page
        end
        {:ok, Repo.preload(page, @page_preloads, force: true)}
      error ->
        error
    end
  end

  @doc """
  Updates a page.
  """
  def update_page(%Page{} = page, attrs) do
    {tag_ids, attrs} = Map.pop(attrs, "tag_ids")

    result =
      page
      |> Page.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, page} ->
        page = if tag_ids != nil do
          update_page_tags_internal(page, tag_ids)
        else
          page
        end
        {:ok, Repo.preload(page, @page_preloads, force: true)}
      error ->
        error
    end
  end

  @doc """
  Updates the tags on a page.
  """
  def update_page_tags(%Page{} = page, tag_ids) when is_list(tag_ids) do
    page = update_page_tags_internal(page, tag_ids)
    {:ok, Repo.preload(page, @page_preloads, force: true)}
  end

  defp update_page_tags_internal(page, tag_ids) when is_list(tag_ids) do
    tags = Repo.all(from t in Tag, where: t.id in ^tag_ids)

    page
    |> Repo.preload(:tags)
    |> Page.tags_changeset(tags)
    |> Repo.update!()
  end

  @doc """
  Deletes a page.
  """
  def delete_page(%Page{} = page) do
    Repo.delete(page)
  end

  # Page Links

  @doc """
  Creates a link from a page to another item.
  """
  def create_page_link(attrs \\ %{}) do
    %PageLink{}
    |> PageLink.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a page link.
  """
  def delete_page_link(%PageLink{} = link) do
    Repo.delete(link)
  end

  @doc """
  Gets links for a page.
  """
  def get_page_links(page_id) do
    from(l in PageLink, where: l.page_id == ^page_id)
    |> Repo.all()
  end

  @doc """
  Finds pages that link to a specific item.
  """
  def find_pages_linking_to(link_type, linked_id) do
    from(p in Page,
      join: l in PageLink, on: l.page_id == p.id,
      where: l.link_type == ^link_type and l.linked_id == ^linked_id
    )
    |> Repo.all()
  end
end
