# simple_test.exs
import Ecto.Query

# Start apps
[:postgrex, :ecto_sql] |> Enum.each(&Application.ensure_all_started/1)

# Start Repo if not started
case MegaPlanner.Repo.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
  e -> IO.inspect(e, label: "Failed to start repo")
end

alias MegaPlanner.Repo
alias MegaPlanner.Templates.TextTemplate
alias MegaPlanner.Households.Household

# Fetch any household
household = Repo.one(from h in Household, limit: 1)
IO.inspect(household && household.id, label: "Household ID")

if household do
  IO.puts "Testing query with ILIKE..."
  query_str = "T"
  search_pattern = "%#{query_str}%"
  
  query = from t in TextTemplate,
    where: t.household_id == ^household.id and t.field_type == "task_title" and ilike(t.value, ^search_pattern),
    select: t.value,
    limit: 10

  {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
  IO.puts "GENERATED SQL:"
  IO.puts sql
  IO.inspect(params, label: "PARAMS")

  try do
    result = Repo.all(query)
    IO.inspect(result, label: "Query Result")
  rescue
    e -> 
      IO.puts "ERROR CAUGHT:"
      IO.inspect(e)
  end
end
