defmodule MegaPlanner.Notes.Notebook do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notebooks" do
    field :name, :string

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    has_many :pages, MegaPlanner.Notes.Page, on_delete: :delete_all
    many_to_many :tags, MegaPlanner.Tags.Tag, join_through: "notebooks_tags", on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notebook, attrs) do
    notebook
    |> cast(attrs, [:name, :user_id, :household_id])
    |> validate_required([:name, :user_id, :household_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:household_id)
  end

  def tags_changeset(notebook, tags) do
    notebook
    |> change()
    |> put_assoc(:tags, tags)
  end
end
