defmodule MegaPlanner.Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def change do
    create table(:notebooks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:notebooks, [:user_id])

    create table(:pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :content, :text
      add :notebook_id, references(:notebooks, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:pages, [:notebook_id])
    create index(:pages, [:user_id])

    create table(:page_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :link_type, :string, null: false
      add :linked_id, :binary_id, null: false
      add :page_id, references(:pages, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:page_links, [:page_id])
    create index(:page_links, [:link_type, :linked_id])
  end
end
