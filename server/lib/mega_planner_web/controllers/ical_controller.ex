defmodule MegaPlannerWeb.IcalController do
  use MegaPlannerWeb, :controller

  alias MegaPlanner.{Calendar, Accounts}

  @doc """
  Generate an iCal feed for a user's tasks.
  Uses a token-based authentication for calendar subscriptions.
  """
  def feed(conn, %{"token" => token} = params) do
    case verify_feed_token(token) do
      {:ok, user_id} ->
        case Accounts.get_user(user_id) do
          nil ->
            conn
            |> put_status(:unauthorized)
            |> text("Invalid token")

          user ->
            generate_ical_feed(conn, user.household_id, params)
        end

      :error ->
        conn
        |> put_status(:unauthorized)
        |> text("Invalid token")
    end
  end

  @doc """
  Generate a feed token for the current user.
  """
  def generate_token(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    token = create_feed_token(user.id)

    # Build the feed URL manually
    base_url = MegaPlannerWeb.Endpoint.url()
    feed_url = "#{base_url}/api/ical/feed?token=#{token}"

    json(conn, %{
      token: token,
      feed_url: feed_url
    })
  end

  # Private functions

  defp generate_ical_feed(conn, household_id, params) do
    # Get tasks for the next 90 days by default
    end_date = Date.add(Date.utc_today(), 90)
    start_date = Date.add(Date.utc_today(), -30)

    opts = [start_date: start_date, end_date: end_date]

    # Filter by type if specified
    opts = case params["type"] do
      "timed" -> Keyword.put(opts, :task_type, "timed")
      "todo" -> Keyword.put(opts, :task_type, "todo")
      _ -> opts
    end

    tasks = Calendar.list_tasks(household_id, opts)

    ical_content = build_ical(tasks)

    conn
    |> put_resp_header("content-type", "text/calendar; charset=utf-8")
    |> put_resp_header("content-disposition", "attachment; filename=\"mega-planner.ics\"")
    |> send_resp(200, ical_content)
  end

  defp build_ical(tasks) do
    events = Enum.map(tasks, &task_to_vevent/1) |> Enum.join("")

    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//MegaPlanner//Tasks//EN
    CALSCALE:GREGORIAN
    METHOD:PUBLISH
    X-WR-CALNAME:MegaPlanner Tasks
    #{events}END:VCALENDAR
    """
  end

  defp task_to_vevent(task) do
    uid = "#{task.id}@megaplanner"
    dtstamp = format_datetime(task.inserted_at)

    {dtstart, dtend} = case {task.date, task.start_time, task.duration_minutes} do
      {date, time, duration} when not is_nil(date) and not is_nil(time) and not is_nil(duration) ->
        # Timed task with duration
        start_dt = combine_date_time(date, time)
        end_dt = DateTime.add(start_dt, duration * 60, :second)
        {format_datetime(start_dt), format_datetime(end_dt)}

      {date, time, _} when not is_nil(date) and not is_nil(time) ->
        # Timed task without duration (default 30 min)
        start_dt = combine_date_time(date, time)
        end_dt = DateTime.add(start_dt, 30 * 60, :second)
        {format_datetime(start_dt), format_datetime(end_dt)}

      {date, _, _} when not is_nil(date) ->
        # All-day task
        {format_date(date), format_date(Date.add(date, 1))}

      _ ->
        # No date - skip
        {nil, nil}
    end

    if dtstart do
      status = case task.status do
        "completed" -> "COMPLETED"
        "in_progress" -> "IN-PROCESS"
        _ -> "NEEDS-ACTION"
      end

      description = task.description || ""
      description = description |> String.replace("\n", "\\n") |> String.replace(",", "\\,")

      """
      BEGIN:VEVENT
      UID:#{uid}
      DTSTAMP:#{dtstamp}
      DTSTART:#{dtstart}
      DTEND:#{dtend}
      SUMMARY:#{escape_ical(task.title)}
      DESCRIPTION:#{escape_ical(description)}
      STATUS:#{status}
      END:VEVENT
      """
    else
      ""
    end
  end

  defp combine_date_time(date, time) do
    {:ok, datetime} = NaiveDateTime.new(date, time)
    DateTime.from_naive!(datetime, "Etc/UTC")
  end

  defp format_datetime(dt) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.to_iso8601(:basic)
    |> String.replace("-", "")
    |> String.replace(":", "")
    |> Kernel.<>("Z")
  end

  defp format_date(date) do
    date
    |> Date.to_iso8601(:basic)
    |> String.replace("-", "")
  end

  defp escape_ical(text) when is_binary(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace(",", "\\,")
    |> String.replace(";", "\\;")
    |> String.replace("\n", "\\n")
  end
  defp escape_ical(_), do: ""

  # Token functions - using simple HMAC for feed tokens
  defp create_feed_token(user_id) do
    secret = Application.get_env(:mega_planner, :secret_key_base, "default_secret")
    timestamp = System.system_time(:second)
    data = "#{user_id}:#{timestamp}"
    signature = :crypto.mac(:hmac, :sha256, secret, data) |> Base.url_encode64(padding: false)
    Base.url_encode64("#{data}:#{signature}", padding: false)
  end

  defp verify_feed_token(token) do
    secret = Application.get_env(:mega_planner, :secret_key_base, "default_secret")

    with {:ok, decoded} <- Base.url_decode64(token, padding: false),
         [user_id, _timestamp, signature] <- String.split(decoded, ":"),
         expected_data <- "#{user_id}:#{String.split(decoded, ":") |> Enum.at(1)}",
         expected_sig <- :crypto.mac(:hmac, :sha256, secret, expected_data) |> Base.url_encode64(padding: false),
         true <- Plug.Crypto.secure_compare(signature, expected_sig) do
      {:ok, user_id}
    else
      _ -> :error
    end
  end
end
