defmodule MegaPlannerWeb.HouseholdController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.Households

  action_fallback MegaPlannerWeb.FallbackController

  @doc """
  Get current household info with members.
  """
  def show(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Households.get_household_with_members(user.household_id) do
      nil ->
        {:error, :not_found}
      household ->
        json(conn, %{data: household_to_json(household)})
    end
  end

  @doc """
  Update household name.
  """
  def update(conn, %{"household" => household_params}) do
    user = Guardian.Plug.current_resource(conn)

    with household when not is_nil(household) <- Households.get_household(user.household_id),
         {:ok, household} <- Households.update_household(household, household_params) do
      household = Households.get_household_with_members(household.id)
      json(conn, %{data: household_to_json(household)})
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Send an invitation to join the household (in-app only, no email sent).
  """
  def invite(conn, %{"email" => email}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, invitation} <- Households.send_invitation(user, email) do
      invitation = Households.get_invitation(invitation.id)
      conn
      |> put_status(:created)
      |> json(%{data: invitation_to_json(invitation)})
    else
      {:error, :cannot_invite_self} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "You cannot invite yourself"})

      {:error, :invitation_already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "An invitation has already been sent to this email"})

      {:error, :already_member} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "This user is already a member of your household"})

      error ->
        error
    end
  end

  @doc """
  List pending invitations sent from this household.
  """
  def list_invitations(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    invitations = Households.list_pending_invitations(user.household_id)
    json(conn, %{data: Enum.map(invitations, &invitation_to_json/1)})
  end

  @doc """
  List pending invitations for the current user (invitations sent to their email).
  """
  def my_invitations(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    invitations = Households.list_invitations_for_email(user.email)
    json(conn, %{data: Enum.map(invitations, &received_invitation_to_json/1)})
  end

  @doc """
  Cancel a pending invitation.
  """
  def cancel_invitation(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with invitation when not is_nil(invitation) <- Households.get_invitation(id),
         true <- invitation.household_id == user.household_id,
         {:ok, _} <- Households.cancel_invitation(invitation) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Leave the current household.
  """
  def leave(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Households.leave_household(user) do
      {:ok, updated_user} ->
        household = Households.get_household_with_members(updated_user.household_id)
        json(conn, %{
          data: household_to_json(household),
          message: "You have left your household and created a new personal one"
        })

      {:error, :only_member} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "You are the only member of this household. You cannot leave."})

      error ->
        error
    end
  end

  @doc """
  Accept an invitation by ID (authenticated user, in-app).
  """
  def accept_invitation(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with invitation when not is_nil(invitation) <- Households.get_invitation(id),
         # Check if invitation email matches user email
         true <- String.downcase(invitation.email) == String.downcase(user.email),
         {:ok, updated_user} <- Households.accept_invitation(invitation, user) do
      household = Households.get_household_with_members(updated_user.household_id)
      json(conn, %{
        data: household_to_json(household),
        message: "Welcome to the household!"
      })
    else
      nil ->
        {:error, :not_found}

      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "This invitation was sent to a different email address"})

      {:error, :invitation_not_pending} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "This invitation has already been used or declined"})

      {:error, :invitation_expired} ->
        conn
        |> put_status(:gone)
        |> json(%{error: "This invitation has expired"})

      {:error, :already_member} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "You are already a member of this household"})

      error ->
        error
    end
  end

  @doc """
  Decline an invitation by ID (authenticated user, in-app).
  """
  def decline_invitation(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)

    with invitation when not is_nil(invitation) <- Households.get_invitation(id),
         # Verify invitation is for this user
         true <- String.downcase(invitation.email) == String.downcase(user.email),
         {:ok, _} <- Households.decline_invitation(invitation) do
      json(conn, %{message: "Invitation declined"})
    else
      nil ->
        {:error, :not_found}

      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "This invitation was sent to a different email address"})

      {:error, :invitation_not_pending} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "This invitation has already been used or declined"})

      error ->
        error
    end
  end

  # JSON helpers

  defp household_to_json(household) do
    %{
      id: household.id,
      name: household.name,
      members: Enum.map(household.users || [], &member_to_json/1),
      inserted_at: household.inserted_at,
      updated_at: household.updated_at
    }
  end

  defp member_to_json(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      avatar_url: user.avatar_url,
      joined_at: user.inserted_at
    }
  end

  defp invitation_to_json(invitation) do
    %{
      id: invitation.id,
      email: invitation.email,
      status: invitation.status,
      expires_at: invitation.expires_at,
      inviter: if(Ecto.assoc_loaded?(invitation.inviter),
        do: %{id: invitation.inviter.id, name: invitation.inviter.name},
        else: nil
      ),
      inserted_at: invitation.inserted_at
    }
  end

  defp received_invitation_to_json(invitation) do
    %{
      id: invitation.id,
      status: invitation.status,
      expires_at: invitation.expires_at,
      household: if(Ecto.assoc_loaded?(invitation.household),
        do: %{id: invitation.household.id, name: invitation.household.name},
        else: nil
      ),
      inviter: if(Ecto.assoc_loaded?(invitation.inviter),
        do: %{id: invitation.inviter.id, name: invitation.inviter.name, email: invitation.inviter.email},
        else: nil
      ),
      inserted_at: invitation.inserted_at
    }
  end
end
