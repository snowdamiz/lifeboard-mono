defmodule MegaPlanner.Accounts do
  @moduledoc """
  The Accounts context handles user management and authentication.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Accounts.{User, UserPreferences}
  alias MegaPlanner.Households.Household

  @doc """
  Gets a single user by ID.
  """
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc """
  Gets a user by provider and provider_id.
  """
  def get_user_by_provider(provider, provider_id) do
    Repo.get_by(User, provider: provider, provider_id: provider_id)
  end

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Creates or updates a user from OAuth data.
  """
  def find_or_create_user_from_oauth(provider, oauth_info) do
    provider_str = to_string(provider)
    provider_id = to_string(oauth_info.uid)

    case get_user_by_provider(provider_str, provider_id) do
      nil ->
        create_user_from_oauth(provider_str, provider_id, oauth_info)

      user ->
        update_user_from_oauth(user, oauth_info)
    end
  end

  defp create_user_from_oauth(provider, provider_id, oauth_info) do
    name = oauth_info.info.name || oauth_info.info.nickname
    email = oauth_info.info.email

    Repo.transaction(fn ->
      # First create the household
      household_name = (name || email) <> "'s Household"
      case %Household{} |> Household.changeset(%{name: household_name}) |> Repo.insert() do
        {:ok, household} ->
          # Then create the user with the household_id
          attrs = %{
            email: email,
            name: name,
            avatar_url: oauth_info.info.image,
            provider: provider,
            provider_id: provider_id,
            household_id: household.id
          }

          case %User{} |> User.changeset(attrs) |> Repo.insert() do
            {:ok, user} -> user
            {:error, changeset} -> Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp update_user_from_oauth(user, oauth_info) do
    attrs = %{
      name: oauth_info.info.name || oauth_info.info.nickname || user.name,
      avatar_url: oauth_info.info.image || user.avatar_url
    }

    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  # ============================================================================
  # User Preferences
  # ============================================================================

  @doc """
  Gets preferences for a user. Creates default preferences if none exist.
  """
  def get_or_create_preferences(user_id) do
    case Repo.get_by(UserPreferences, user_id: user_id) do
      nil ->
        {:ok, prefs} = create_preferences(%{user_id: user_id})
        prefs
      prefs ->
        prefs
    end
  end

  @doc """
  Gets preferences for a user.
  """
  def get_preferences(user_id) do
    Repo.get_by(UserPreferences, user_id: user_id)
  end

  @doc """
  Creates preferences for a user.
  """
  def create_preferences(attrs) do
    %UserPreferences{}
    |> UserPreferences.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user's preferences.
  """
  def update_preferences(%UserPreferences{} = prefs, attrs) do
    prefs
    |> UserPreferences.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates specific preference values for a user. Creates preferences if they don't exist.
  """
  def set_preferences(user_id, attrs) do
    prefs = get_or_create_preferences(user_id)
    update_preferences(prefs, attrs)
  end
end
