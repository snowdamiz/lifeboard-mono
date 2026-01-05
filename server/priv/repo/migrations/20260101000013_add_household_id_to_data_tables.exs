defmodule MegaPlanner.Repo.Migrations.AddHouseholdIdToDataTables do
  use Ecto.Migration

  def up do
    # First, create households for each user and associate them
    execute """
    DO $$
    DECLARE
      user_record RECORD;
      new_household_id UUID;
    BEGIN
      FOR user_record IN SELECT id, name, email FROM users WHERE household_id IS NULL
      LOOP
        new_household_id := gen_random_uuid();
        INSERT INTO households (id, name, inserted_at, updated_at)
        VALUES (new_household_id, COALESCE(user_record.name, user_record.email) || '''s Household', NOW(), NOW());
        UPDATE users SET household_id = new_household_id WHERE id = user_record.id;
      END LOOP;
    END $$;
    """

    # Add household_id to tasks
    alter table(:tasks) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE tasks SET household_id = (SELECT household_id FROM users WHERE users.id = tasks.user_id)"

    # Add household_id to task_templates
    alter table(:task_templates) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE task_templates SET household_id = (SELECT household_id FROM users WHERE users.id = task_templates.user_id)"

    # Add household_id to tags
    alter table(:tags) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE tags SET household_id = (SELECT household_id FROM users WHERE users.id = tags.user_id)"

    # Add household_id to inventory_sheets
    alter table(:inventory_sheets) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE inventory_sheets SET household_id = (SELECT household_id FROM users WHERE users.id = inventory_sheets.user_id)"

    # Add household_id to shopping_list_items
    alter table(:shopping_list_items) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE shopping_list_items SET household_id = (SELECT household_id FROM users WHERE users.id = shopping_list_items.user_id)"

    # Add household_id to budget_sources
    alter table(:budget_sources) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE budget_sources SET household_id = (SELECT household_id FROM users WHERE users.id = budget_sources.user_id)"

    # Add household_id to budget_entries
    alter table(:budget_entries) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE budget_entries SET household_id = (SELECT household_id FROM users WHERE users.id = budget_entries.user_id)"

    # Add household_id to notebooks
    alter table(:notebooks) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE notebooks SET household_id = (SELECT household_id FROM users WHERE users.id = notebooks.user_id)"

    # Add household_id to goals
    alter table(:goals) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE goals SET household_id = (SELECT household_id FROM users WHERE users.id = goals.user_id)"

    # Add household_id to habits
    alter table(:habits) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE habits SET household_id = (SELECT household_id FROM users WHERE users.id = habits.user_id)"

    # Add household_id to notifications
    alter table(:notifications) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE notifications SET household_id = (SELECT household_id FROM users WHERE users.id = notifications.user_id)"

    # Add household_id to notification_preferences
    alter table(:notification_preferences) do
      add :household_id, references(:households, type: :binary_id, on_delete: :delete_all)
    end
    execute "UPDATE notification_preferences SET household_id = (SELECT household_id FROM users WHERE users.id = notification_preferences.user_id)"

    # Create indexes for all household_id columns
    create index(:tasks, [:household_id])
    create index(:task_templates, [:household_id])
    create index(:tags, [:household_id])
    create index(:inventory_sheets, [:household_id])
    create index(:shopping_list_items, [:household_id])
    create index(:budget_sources, [:household_id])
    create index(:budget_entries, [:household_id])
    create index(:notebooks, [:household_id])
    create index(:goals, [:household_id])
    create index(:habits, [:household_id])
    create index(:notifications, [:household_id])
    create index(:notification_preferences, [:household_id])
  end

  def down do
    drop index(:tasks, [:household_id])
    drop index(:task_templates, [:household_id])
    drop index(:tags, [:household_id])
    drop index(:inventory_sheets, [:household_id])
    drop index(:shopping_list_items, [:household_id])
    drop index(:budget_sources, [:household_id])
    drop index(:budget_entries, [:household_id])
    drop index(:notebooks, [:household_id])
    drop index(:goals, [:household_id])
    drop index(:habits, [:household_id])
    drop index(:notifications, [:household_id])
    drop index(:notification_preferences, [:household_id])

    alter table(:tasks) do
      remove :household_id
    end

    alter table(:task_templates) do
      remove :household_id
    end

    alter table(:tags) do
      remove :household_id
    end

    alter table(:inventory_sheets) do
      remove :household_id
    end

    alter table(:shopping_list_items) do
      remove :household_id
    end

    alter table(:budget_sources) do
      remove :household_id
    end

    alter table(:budget_entries) do
      remove :household_id
    end

    alter table(:notebooks) do
      remove :household_id
    end

    alter table(:goals) do
      remove :household_id
    end

    alter table(:habits) do
      remove :household_id
    end

    alter table(:notifications) do
      remove :household_id
    end

    alter table(:notification_preferences) do
      remove :household_id
    end
  end
end
