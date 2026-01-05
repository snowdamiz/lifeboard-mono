defmodule MegaPlanner.Repo do
  use Ecto.Repo,
    otp_app: :mega_planner,
    adapter: Ecto.Adapters.Postgres
end
