defmodule MegaPlanner.Notes do
  @moduledoc """
  The Notes context handles notebooks, pages, and links.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Notes.{Notebook, Page, PageLink}

  # Notebooks

  @doc """
  Returns the list of notebooks for a household.
  """
  def list_notebooks(household_id) do
    from(n in Notebook, where: n.household_id == ^household_id, order_by: [asc: n.name])
    |> Repo.all()
  end

  @doc """
  Gets a single notebook.
  """
  def get_notebook(id) do
    Repo.get(Notebook, id)
  end

  @doc """
  Gets a notebook for a specific household.
  """
  def get_household_notebook(household_id, id) do
    Repo.get_by(Notebook, id: id, household_id: household_id)
  end

  @doc """
  Creates a notebook.
  """
  def create_notebook(attrs \\ %{}) do
    %Notebook{}
    |> Notebook.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a notebook.
  """
  def update_notebook(%Notebook{} = notebook, attrs) do
    notebook
    |> Notebook.changeset(attrs)
    |> Repo.update()
  end

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
  def list_pages(notebook_id) do
    from(p in Page, where: p.notebook_id == ^notebook_id, order_by: [desc: p.updated_at])
    |> Repo.all()
    |> Repo.preload(:links)
  end

  @doc """
  Gets a single page.
  """
  def get_page(id) do
    Page
    |> Repo.get(id)
    |> Repo.preload(:links)
  end

  @doc """
  Gets a page that belongs to a notebook in the household.
  """
  def get_household_page(household_id, id) do
    result = from(p in Page,
      join: n in Notebook, on: p.notebook_id == n.id,
      where: p.id == ^id and n.household_id == ^household_id,
      preload: [:links]
    )
    |> Repo.one()

    result
  end

  @doc """
  Creates a page.
  """
  def create_page(attrs \\ %{}) do
    %Page{}
    |> Page.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, page} -> {:ok, Repo.preload(page, :links)}
      error -> error
    end
  end

  @doc """
  Updates a page.
  """
  def update_page(%Page{} = page, attrs) do
    page
    |> Page.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, page} -> {:ok, Repo.preload(page, :links, force: true)}
      error -> error
    end
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
