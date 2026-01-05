defmodule MegaPlanner.Notes.Page do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pages" do
    field :title, :string
    field :content, :string

    belongs_to :notebook, MegaPlanner.Notes.Notebook
    belongs_to :user, MegaPlanner.Accounts.User
    has_many :links, MegaPlanner.Notes.PageLink

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(page, attrs) do
    page
    |> cast(attrs, [:title, :content, :notebook_id, :user_id])
    |> validate_required([:title, :notebook_id, :user_id])
    |> foreign_key_constraint(:notebook_id)
    |> foreign_key_constraint(:user_id)
  end
end
