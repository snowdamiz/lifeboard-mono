defmodule MegaPlanner.AccountsFixtures do
  alias MegaPlanner.{Repo, Accounts, Households}
  alias MegaPlanner.Households.Household

  def household_fixture(attrs \\ %{}) do
    {:ok, household} =
      attrs
      |> Enum.into(%{name: "Test Household #{System.unique_integer()}"})
      |> Households.create_household()

    household
  end

  def user_fixture(attrs \\ %{}) do
    household = household_fixture()

    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "user#{System.unique_integer()}@example.com",
        name: "Test User",
        provider: "google",
        provider_id: "#{System.unique_integer()}",
        household_id: household.id
      })
      |> Accounts.create_user()

    user
  end
end
