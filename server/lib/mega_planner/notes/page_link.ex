defmodule MegaPlanner.Notes.PageLink do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @link_types ["task", "inventory_item", "budget_entry", "page"]

  schema "page_links" do
    field :link_type, :string
    field :linked_id, :binary_id

    belongs_to :page, MegaPlanner.Notes.Page

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:link_type, :linked_id, :page_id])
    |> validate_required([:link_type, :linked_id, :page_id])
    |> validate_inclusion(:link_type, @link_types)
    |> foreign_key_constraint(:page_id)
  end
end
