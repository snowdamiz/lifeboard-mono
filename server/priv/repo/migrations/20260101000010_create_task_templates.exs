defmodule MegaPlanner.Repo.Migrations.CreateTaskTemplates do
  use Ecto.Migration

  def change do
    create table(:task_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      add :name, :string, null: false
      add :description, :text
      add :category, :string

      # Template task data
      add :title, :string, null: false
      add :task_description, :text
      add :duration_minutes, :integer
      add :priority, :integer, default: 1
      add :task_type, :string, default: "todo"
      add :default_steps, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:task_templates, [:user_id])
    create index(:task_templates, [:user_id, :category])
  end
end
