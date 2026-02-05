defmodule MegaPlannerWeb.Plugs.TestModeAuth do
  @moduledoc """
  Test Mode Authentication Bypass.

  When TEST_MODE=true environment variable is set AND we're in :dev or :test environment,
  this plug bypasses normal authentication by loading the first user from the database.

  SECURITY SAFEGUARDS:
  1. Only works in :dev or :test MIX_ENV
  2. Requires TEST_MODE=true environment variable
  3. Logs a warning when active

  This enables Playwright E2E tests to run without OAuth login.
  """

  import Plug.Conn
  import Ecto.Query, only: [from: 2]
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    if test_mode_enabled?() do
      bypass_auth(conn)
    else
      conn
    end
  end

  defp test_mode_enabled? do
    # Only enable in dev or test environments
    env = Application.get_env(:mega_planner, :env, :dev)

    cond do
      env == :prod ->
        false

      System.get_env("TEST_MODE") == "true" ->
        Logger.warning("⚠️  TEST_MODE active - authentication bypassed!")
        true

      true ->
        false
    end
  end

  defp bypass_auth(conn) do
    # Load first user from database for test mode
    query = from u in MegaPlanner.Accounts.User, limit: 1
    case MegaPlanner.Repo.all(query) do
      [user | _] ->
        Logger.debug("TEST_MODE: Using existing user #{user.email}")
        conn
        |> assign(:current_user, user)
        |> Guardian.Plug.put_current_resource(user)

      [] ->
        # No users exist - create a test user
        create_and_assign_test_user(conn)
    end
  end

  defp create_and_assign_test_user(conn) do
    # Ensure a household exists first
    household = get_or_create_test_household()

    user_attrs = %{
      email: "test@playwright.local",
      name: "Playwright Test User",
      provider: "test",
      provider_id: "test_user_001",
      household_id: household.id
    }

    case MegaPlanner.Repo.insert(
           MegaPlanner.Accounts.User.changeset(%MegaPlanner.Accounts.User{}, user_attrs)
         ) do
      {:ok, user} ->
        Logger.info("Created test user: #{user.email}")

        conn
        |> assign(:current_user, user)
        |> Guardian.Plug.put_current_resource(user)

      {:error, _} ->
        # If user creation fails, just return conn without auth
        Logger.error("Failed to create test user")
        conn
    end
  end

  defp get_or_create_test_household do
    alias MegaPlanner.Households.Household
    alias MegaPlanner.Repo

    query = from h in Household, limit: 1
    case Repo.all(query) do
      [household | _] ->
        household

      [] ->
        {:ok, household} =
          %Household{}
          |> Household.changeset(%{name: "Test Household"})
          |> Repo.insert()

        household
    end
  end
end
