defmodule MegaPlanner.Templates do
  @moduledoc """
  The Templates context.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Templates.TextTemplate

  @doc """
  Returns a list of matching template values.
  """
  def suggest_templates(household_id, field_type, query) do
    search_pattern = "%#{query}%"
    
    from(t in TextTemplate,
      where: t.household_id == ^household_id and t.field_type == ^field_type and ilike(t.value, ^search_pattern),
      select: t.value,
      distinct: true,
      order_by: [asc: t.value],
      limit: 10
    )
    |> Repo.all()
  end

  @doc """
  Creates a text template.
  """
  def create_template(attrs \\ %{}) do
    %TextTemplate{}
    |> TextTemplate.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Deletes a text template by household, type, and value.
  """
  def delete_template(household_id, field_type, value) do
    from(t in TextTemplate,
      where: t.household_id == ^household_id and t.field_type == ^field_type and t.value == ^value
    )
    |> Repo.delete_all()
  end
end
