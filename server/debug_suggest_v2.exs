# debug_suggest_v2.exs

# Load config
IO.puts "Starting dependencies..."
{:ok, _} = Application.ensure_all_started(:logger)
{:ok, _} = Application.ensure_all_started(:ssl)
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Application.ensure_all_started(:postgrex)

IO.puts "Starting Repo..."
# We need to ensure the Repo is started. 
# Depending on how the app is structured, we might need to start the app :mega_planner but exclude the endpoint?
# Calling start_link directly on Repo might work if config is loaded.
case MegaPlanner.Repo.start_link() do
  {:ok, _pid} -> IO.puts "Repo started."
  {:error, {:already_started, _}} -> IO.puts "Repo already started."
  {:error, reason} -> IO.puts "Failed to start Repo: #{inspect(reason)}"
end

alias MegaPlanner.Repo
alias MegaPlanner.Accounts.User
alias MegaPlanner.Templates
import Ecto.Query

# Get the first user
user = Repo.one(from u in User, limit: 1)

if user do
  IO.puts "Found user: #{user.email} with household_id: #{user.household_id}"
  
  if user.household_id do
    try do
      IO.puts "Attempting to suggest templates..."
      result = Templates.suggest_templates(user.household_id, "task_title", "T")
      IO.inspect(result, label: "Result")
    rescue
      e -> 
        IO.puts "An error occurred:"
        IO.inspect(e, label: "Error")
        IO.puts Exception.format(:error, e, __STACKTRACE__)
    end
  else
    IO.puts "User has no household_id"
  end
else
  IO.puts "No user found"
end
