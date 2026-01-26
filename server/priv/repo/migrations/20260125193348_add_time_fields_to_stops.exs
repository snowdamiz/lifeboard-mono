defmodule MegaPlanner.Repo.Migrations.AddTimeFieldsToStops do
  use Ecto.Migration

  def change do
    alter table(:stops) do
      add :time_arrived, :time
      add :time_left, :time
    end
  end
end
