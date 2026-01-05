defmodule MegaPlanner.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      # Navigation preferences
      add :nav_order, {:array, :string}, default: []

      # Dashboard preferences
      add :dashboard_widgets, :jsonb, default: "[]"

      # Theme preferences
      add :theme, :string, default: "system"

      # Other preferences can be added to this JSONB field
      add :settings, :jsonb, default: "{}"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_preferences, [:user_id])
  end
end

