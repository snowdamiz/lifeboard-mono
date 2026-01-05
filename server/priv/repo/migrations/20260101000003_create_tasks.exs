defmodule MegaPlanner.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :date, :date
      add :start_time, :time
      add :duration_minutes, :integer
      add :priority, :integer, default: 0
      add :status, :string, default: "not_started"
      add :is_recurring, :boolean, default: false
      add :recurrence_rule, :map
      add :task_type, :string, default: "todo"
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_task_id, references(:tasks, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:user_id])
    create index(:tasks, [:date])
    create index(:tasks, [:user_id, :date])
    create index(:tasks, [:parent_task_id])

    create table(:task_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :string, null: false
      add :completed, :boolean, default: false
      add :position, :integer, default: 0
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:task_steps, [:task_id])

    create table(:tasks_tags, primary_key: false) do
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:tasks_tags, [:task_id, :tag_id])
  end
end
