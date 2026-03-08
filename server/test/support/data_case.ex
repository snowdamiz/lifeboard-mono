defmodule MegaPlanner.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias MegaPlanner.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MegaPlanner.DataCase
    end
  end

  setup tags do
    MegaPlanner.DataCase.setup_sandbox(tags)
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MegaPlanner.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
