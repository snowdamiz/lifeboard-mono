alias MegaPlanner.{Repo, Tags.Tag, Calendar, Accounts.User}
import Ecto.Query

# Get first user
user = Repo.one(from u in User, limit: 1)
IO.puts("User: #{user.id}, household: #{user.household_id}")

# Get or create a tag
tag = Repo.one(from t in Tag, where: t.household_id == ^user.household_id, limit: 1)

if !tag do
  IO.puts("Creating a test tag...")
  {:ok, tag} = MegaPlanner.Tags.create_tag(%{
    "name" => "Test Tag",
    "color" => "#FF5733",
    "household_id" => user.household_id
  })
end

IO.puts("Tag: #{tag.id} - #{tag.name}")

# Create a task with tag_ids and a step
attrs = %{
  "title" => "Test Task #{:rand.uniform(1000)}",
  "user_id" => user.id,
  "household_id" => user.household_id,
  "tag_ids" => [tag.id],
  "date" => Date.to_iso8601(Date.utc_today()),
  "steps" => [
    %{"content" => "Test step 1", "completed" => false, "position" => 0}
  ]
}

IO.puts("\n=== Creating task with tag and step ===")
IO.puts("Tag IDs: #{inspect(attrs["tag_ids"])}")

case Calendar.create_task(attrs) do
  {:ok, task} ->
    IO.puts("\n✓ Task created successfully!")
    IO.puts("  Task ID: #{task.id}")
    IO.puts("  Title: #{task.title}")
    IO.puts("  Steps count: #{length(task.steps)}")
    IO.puts("  Tags count: #{length(task.tags)}")
    
    if length(task.tags) > 0 do
      IO.puts("  Tags: #{Enum.map(task.tags, & &1.name) |> Enum.join(", ")}")
      IO.puts("\n✓✓ SUCCESS: Tags were saved correctly!")
    else
      IO.puts("\n✗✗ FAILURE: No tags on task!")
    end
    
    # Now reload the task to verify persistence
    IO.puts("\n=== Reloading task from database ===")
    reloaded = Calendar.get_task(task.id)
    IO.puts("  Reloaded tags count: #{length(reloaded.tags)}")
    
    if length(reloaded.tags) > 0 do
      IO.puts("  Reloaded tags: #{Enum.map(reloaded.tags, & &1.name) |> Enum.join(", ")}")
      IO.puts("\n✓✓✓ COMPLETE SUCCESS: Tags persisted correctly!")
    else
      IO.puts("\n✗✗✗ FAILURE: Tags lost after reload!")
    end
    
  {:error, changeset} ->
    IO.puts("\n✗ Error creating task:")
    IO.puts("  #{inspect(changeset.errors)}")
end
