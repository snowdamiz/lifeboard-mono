defmodule MegaPlanner.Households do
  @moduledoc """
  The Households context handles household management, memberships, and invitations.
  """

  import Ecto.Query, warn: false
  alias MegaPlanner.Repo
  alias MegaPlanner.Households.{Household, Invitation}
  alias MegaPlanner.Accounts.User

  @invite_expiry_days 7

  # Households

  @doc """
  Gets a household by ID.
  """
  def get_household(id) do
    Repo.get(Household, id)
  end

  @doc """
  Gets a household with members preloaded.
  """
  def get_household_with_members(id) do
    Household
    |> Repo.get(id)
    |> Repo.preload(:users)
  end

  @doc """
  Creates a household for a new user.
  """
  def create_household_for_user(%User{} = user) do
    name = (user.name || user.email) <> "'s Household"

    Repo.transaction(fn ->
      case create_household(%{name: name}) do
        {:ok, household} ->
          case update_user_household(user, household.id) do
            {:ok, updated_user} ->
              {household, updated_user}
            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Creates a household.
  """
  def create_household(attrs \\ %{}) do
    %Household{}
    |> Household.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a household.
  """
  def update_household(%Household{} = household, attrs) do
    household
    |> Household.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all members of a household.
  """
  def list_members(household_id) do
    from(u in User, where: u.household_id == ^household_id, order_by: [asc: u.inserted_at])
    |> Repo.all()
  end

  @doc """
  Updates a user's household_id.
  """
  def update_user_household(%User{} = user, household_id) do
    user
    |> Ecto.Changeset.change(%{household_id: household_id})
    |> Repo.update()
  end

  # Invitations

  @doc """
  Sends an invitation to join a household.
  """
  def send_invitation(%User{} = inviter, email) do
    # Check if user is trying to invite themselves
    if String.downcase(email) == String.downcase(inviter.email) do
      {:error, :cannot_invite_self}
    else
      # Check if there's already a pending invitation for this email to this household
      existing = get_pending_invitation_for_email(inviter.household_id, email)

      if existing do
        {:error, :invitation_already_exists}
      else
        # Check if the invitee is already in this household
        invitee = Repo.get_by(User, email: email)
        if invitee && invitee.household_id == inviter.household_id do
          {:error, :already_member}
        else
          create_invitation(inviter, email)
        end
      end
    end
  end

  defp create_invitation(%User{} = inviter, email) do
    token = generate_token()
    expires_at = DateTime.utc_now() |> DateTime.add(@invite_expiry_days * 24 * 60 * 60, :second)

    attrs = %{
      email: email,
      token: token,
      status: "pending",
      expires_at: expires_at,
      household_id: inviter.household_id,
      inviter_id: inviter.id
    }

    %Invitation{}
    |> Invitation.changeset(attrs)
    |> Repo.insert()
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @doc """
  Gets an invitation by token.
  """
  def get_invitation_by_token(token) do
    Invitation
    |> Repo.get_by(token: token)
    |> Repo.preload([:household, :inviter])
  end

  @doc """
  Gets a pending invitation for an email in a household.
  """
  def get_pending_invitation_for_email(household_id, email) do
    from(i in Invitation,
      where: i.household_id == ^household_id and
             i.email == ^email and
             i.status == "pending"
    )
    |> Repo.one()
  end

  @doc """
  Lists pending invitations sent by a household.
  """
  def list_pending_invitations(household_id) do
    from(i in Invitation,
      where: i.household_id == ^household_id and i.status == "pending",
      order_by: [desc: i.inserted_at],
      preload: [:inviter]
    )
    |> Repo.all()
  end

  @doc """
  Lists invitations for a household (all statuses).
  """
  def list_invitations(household_id) do
    from(i in Invitation,
      where: i.household_id == ^household_id,
      order_by: [desc: i.inserted_at],
      preload: [:inviter]
    )
    |> Repo.all()
  end

  @doc """
  Lists pending invitations sent to a specific email address.
  Used to show users invitations they've received.
  """
  def list_invitations_for_email(email) do
    now = DateTime.utc_now()
    from(i in Invitation,
      where: i.email == ^email and
             i.status == "pending" and
             i.expires_at > ^now,
      order_by: [desc: i.inserted_at],
      preload: [:household, :inviter]
    )
    |> Repo.all()
  end

  @doc """
  Gets an invitation by ID.
  """
  def get_invitation(id) do
    Invitation
    |> Repo.get(id)
    |> Repo.preload([:household, :inviter])
  end

  @doc """
  Cancels an invitation.
  """
  def cancel_invitation(%Invitation{} = invitation) do
    Repo.delete(invitation)
  end

  @doc """
  Accepts an invitation and merges the user into the household.
  """
  def accept_invitation(%Invitation{} = invitation, %User{} = user) do
    cond do
      invitation.status != "pending" ->
        {:error, :invitation_not_pending}

      DateTime.compare(invitation.expires_at, DateTime.utc_now()) == :lt ->
        # Mark as expired
        invitation
        |> Invitation.status_changeset("expired")
        |> Repo.update()
        {:error, :invitation_expired}

      user.household_id == invitation.household_id ->
        {:error, :already_member}

      true ->
        do_accept_invitation(invitation, user)
    end
  end

  defp do_accept_invitation(invitation, user) do
    Repo.transaction(fn ->
      old_household_id = user.household_id
      new_household_id = invitation.household_id

      # Update user's household
      case update_user_household(user, new_household_id) do
        {:ok, updated_user} ->
          # Merge all user's data into the new household
          merge_user_data(user.id, old_household_id, new_household_id)

          # Mark invitation as accepted
          invitation
          |> Invitation.status_changeset("accepted")
          |> Repo.update!()

          # Clean up old household if empty
          cleanup_empty_household(old_household_id)

          updated_user

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp merge_user_data(user_id, old_household_id, new_household_id) do
    # Update all data owned by the user to the new household
    # Tasks
    from(t in MegaPlanner.Calendar.Task,
      where: t.user_id == ^user_id and t.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    # Task templates
    from(t in MegaPlanner.Calendar.TaskTemplate,
      where: t.user_id == ^user_id and t.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    # Tags
    from(t in MegaPlanner.Tags.Tag,
      where: t.user_id == ^user_id and t.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    # Inventory sheets
    from(s in MegaPlanner.Inventory.Sheet,
      where: s.user_id == ^user_id and s.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    # Shopping list items
    from(s in MegaPlanner.Inventory.ShoppingListItem,
      where: s.user_id == ^user_id and s.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    # Budget sources
    from(b in MegaPlanner.Budget.Source,
      where: b.user_id == ^user_id and b.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    # Budget entries
    from(b in MegaPlanner.Budget.Entry,
      where: b.user_id == ^user_id and b.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    # Notebooks
    from(n in MegaPlanner.Notes.Notebook,
      where: n.user_id == ^user_id and n.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    # Goals
    from(g in MegaPlanner.Goals.Goal,
      where: g.user_id == ^user_id and g.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    # Habits
    from(h in MegaPlanner.Goals.Habit,
      where: h.user_id == ^user_id and h.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    # Notifications
    from(n in MegaPlanner.Notifications.Notification,
      where: n.user_id == ^user_id and n.household_id == ^old_household_id
    )
    |> Repo.update_all(set: [household_id: new_household_id])

    :ok
  end

  defp cleanup_empty_household(household_id) do
    # Check if household has any remaining members
    member_count = from(u in User, where: u.household_id == ^household_id, select: count())
                   |> Repo.one()

    if member_count == 0 do
      # Delete the empty household
      from(h in Household, where: h.id == ^household_id)
      |> Repo.delete_all()
    end

    :ok
  end

  @doc """
  Declines an invitation.
  """
  def decline_invitation(%Invitation{} = invitation) do
    if invitation.status != "pending" do
      {:error, :invitation_not_pending}
    else
      invitation
      |> Invitation.status_changeset("declined")
      |> Repo.update()
    end
  end

  @doc """
  Allows a user to leave their current household and create a new personal one.
  """
  def leave_household(%User{} = user) do
    # Check if user is the only member
    member_count = from(u in User, where: u.household_id == ^user.household_id, select: count())
                   |> Repo.one()

    if member_count == 1 do
      {:error, :only_member}
    else
      Repo.transaction(fn ->
        old_household_id = user.household_id

        # Create new personal household
        name = (user.name || user.email) <> "'s Household"
        case create_household(%{name: name}) do
          {:ok, new_household} ->
            # Move user's personal data to new household
            move_user_data_to_new_household(user.id, old_household_id, new_household.id)

            # Update user's household
            case update_user_household(user, new_household.id) do
              {:ok, updated_user} ->
                updated_user
              {:error, changeset} ->
                Repo.rollback(changeset)
            end

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end
  end

  defp move_user_data_to_new_household(user_id, _old_household_id, new_household_id) do
    # Note: When leaving, we only move data that was originally created by this user
    # Tasks created by this user
    from(t in MegaPlanner.Calendar.Task, where: t.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    # Task templates created by this user
    from(t in MegaPlanner.Calendar.TaskTemplate, where: t.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    # Tags created by this user
    from(t in MegaPlanner.Tags.Tag, where: t.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    # Inventory sheets created by this user
    from(s in MegaPlanner.Inventory.Sheet, where: s.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    # Shopping list items for this user
    from(s in MegaPlanner.Inventory.ShoppingListItem, where: s.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    # Budget sources created by this user
    from(b in MegaPlanner.Budget.Source, where: b.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    # Budget entries created by this user
    from(b in MegaPlanner.Budget.Entry, where: b.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    # Notebooks created by this user
    from(n in MegaPlanner.Notes.Notebook, where: n.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    # Goals created by this user
    from(g in MegaPlanner.Goals.Goal, where: g.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    # Habits created by this user
    from(h in MegaPlanner.Goals.Habit, where: h.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    # Notifications for this user
    from(n in MegaPlanner.Notifications.Notification, where: n.user_id == ^user_id)
    |> Repo.update_all(set: [household_id: new_household_id])

    :ok
  end
end
