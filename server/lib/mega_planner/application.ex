defmodule MegaPlanner.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MegaPlannerWeb.Telemetry,
      MegaPlanner.Repo,
      {Phoenix.PubSub, name: MegaPlanner.PubSub},
      {Finch, name: MegaPlanner.Finch},
      MegaPlannerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MegaPlanner.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MegaPlannerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
