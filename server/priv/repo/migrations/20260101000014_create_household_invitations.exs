defmodule MegaPlanner.Repo.Migrations.CreateHouseholdInvitations do
  use Ecto.Migration

  def change do
    create table(:household_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :token, :string, null: false
      add :status, :string, default: "pending", null: false
      add :expires_at, :utc_datetime, null: false
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all), null: false
      add :inviter_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:household_invitations, [:token])
    create index(:household_invitations, [:household_id])
    create index(:household_invitations, [:email])
    create index(:household_invitations, [:inviter_id])
  end
end
