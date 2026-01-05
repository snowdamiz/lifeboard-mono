defmodule MegaPlanner.Notes.Notebook do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notebooks" do
    field :name, :string

    belongs_to :user, MegaPlanner.Accounts.User
    belongs_to :household, MegaPlanner.Households.Household
    has_many :pages, MegaPlanner.Notes.Page

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
end
