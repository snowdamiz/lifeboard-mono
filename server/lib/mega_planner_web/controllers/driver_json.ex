defmodule MegaPlannerWeb.DriverJSON do
  alias MegaPlanner.Receipts.Driver

  @doc """
  Renders a list of drivers.
  """
  def index(%{drivers: drivers}) do
    %{data: for(driver <- drivers, do: data(driver))}
  end

  @doc """
  Renders a single driver.
  """
  def show(%{driver: driver}) do
    %{data: data(driver)}
  end

  defp data(%Driver{} = driver) do
    %{
      id: driver.id,
      name: driver.name
    }
  end
end
