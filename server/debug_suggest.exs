# debug_suggest.exs
alias MegaPlanner.Repo
alias MegaPlanner.Accounts.User
alias MegaPlanner.Templates

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
