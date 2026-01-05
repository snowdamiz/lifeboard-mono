defmodule MegaPlanner.Guardian do
  use Guardian, otp_app: :mega_planner

  alias MegaPlanner.Accounts

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end

  @doc """
  Creates an access token (short-lived, 15 minutes)
  """
  def create_access_token(user) do
    encode_and_sign(user, %{}, token_type: "access", ttl: {15, :minutes})
  end

  @doc """
  Creates a refresh token (long-lived, 30 days)
  """
  def create_refresh_token(user) do
    encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})
  end

  @doc """
  Creates both access and refresh tokens for a user
  """
  def create_tokens(user) do
    with {:ok, access_token, _access_claims} <- create_access_token(user),
         {:ok, refresh_token, _refresh_claims} <- create_refresh_token(user) do
      {:ok, %{access_token: access_token, refresh_token: refresh_token}}
    end
  end

  @doc """
  Exchanges a refresh token for a new access token
  """
  def exchange_refresh_token(refresh_token) do
    with {:ok, claims} <- decode_and_verify(refresh_token, %{"typ" => "refresh"}),
         {:ok, user} <- resource_from_claims(claims),
         {:ok, new_access_token, _claims} <- create_access_token(user) do
      {:ok, new_access_token, user}
    else
      {:error, :token_expired} -> {:error, :refresh_token_expired}
      {:error, reason} -> {:error, reason}
    end
  end
end
