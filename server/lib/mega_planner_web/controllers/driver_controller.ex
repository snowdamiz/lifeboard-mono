defmodule MegaPlannerWeb.DriverController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Receipts
  alias MegaPlanner.Receipts.Driver

  action_fallback MegaPlannerWeb.FallbackController

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    drivers = Receipts.list_drivers(user.household_id)
    render(conn, :index, drivers: drivers)
  end

  def create(conn, %{"driver" => driver_params}) do
    user = Guardian.Plug.current_resource(conn)
    driver_params = driver_params
      |> Map.put("user_id", user.id)
      |> Map.put("household_id", user.household_id)

    with {:ok, %Driver{} = driver} <- Receipts.create_driver(driver_params) do
      conn
      |> put_status(:created)
      |> render(:show, driver: driver)
    end
  end
end
