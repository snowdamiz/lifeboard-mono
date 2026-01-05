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
end
