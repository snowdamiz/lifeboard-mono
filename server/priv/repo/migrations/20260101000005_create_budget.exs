defmodule MegaPlanner.Repo.Migrations.CreateBudget do
  use Ecto.Migration

  def change do
    create table(:budget_sources, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :amount, :decimal, precision: 12, scale: 2
      add :is_recurring, :boolean, default: false
      add :recurrence_rule, :map
      add :tags, {:array, :string}, default: []
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:budget_sources, [:user_id])
    create index(:budget_sources, [:type])

    create table(:budget_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :amount, :decimal, precision: 12, scale: 2, null: false
      add :type, :string, null: false
      add :notes, :text
      add :source_id, references(:budget_sources, type: :binary_id, on_delete: :nilify_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:budget_entries, [:user_id])
    create index(:budget_entries, [:date])
    create index(:budget_entries, [:user_id, :date])
    create index(:budget_entries, [:source_id])
  end
end
