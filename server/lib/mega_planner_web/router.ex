defmodule MegaPlannerWeb.Router do
  use MegaPlannerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  pipeline :api_auth do
    plug MegaPlannerWeb.Plugs.AuthPipeline
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # OAuth routes
  scope "/auth", MegaPlannerWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :logout
  end

  # Token refresh route (public, doesn't need auth)
  scope "/auth", MegaPlannerWeb do
    pipe_through :api

    post "/refresh", AuthController, :refresh
  end

  # Public API routes
  scope "/api", MegaPlannerWeb do
    pipe_through :api

    get "/health", HealthController, :index

    # iCal feed (public with token auth)
    get "/ical/feed", IcalController, :feed
  end

  # Protected API routes
  scope "/api", MegaPlannerWeb do
    pipe_through [:api, :api_auth]

    get "/me", UserController, :me

    # User Preferences
    get "/preferences", PreferencesController, :show
    put "/preferences", PreferencesController, :update

    # Task Templates
    resources "/templates", TemplateController, except: [:new, :edit]
    post "/templates/:template_id/apply", TemplateController, :apply

    # Tasks
    resources "/tasks", TaskController, except: [:new, :edit] do
      post "/steps", TaskStepController, :create
      put "/steps/:step_id", TaskStepController, :update
      delete "/steps/:step_id", TaskStepController, :delete
      put "/reorder", TaskController, :reorder
    end

    # Inventory
    scope "/inventory" do
      resources "/sheets", InventorySheetController, except: [:new, :edit]
      resources "/items", InventoryItemController, except: [:new, :edit, :index]
    end

    # Shopping Lists
    resources "/shopping-lists", ShoppingListController, except: [:new, :edit, :update] do
      post "/items", ShoppingListController, :create_item
      put "/items/:id", ShoppingListController, :update_item
      delete "/items/:id", ShoppingListController, :delete_item
    end
    put "/shopping-lists/:id", ShoppingListController, :update_list
    post "/shopping-lists/generate", ShoppingListController, :generate
    get "/shopping-items", ShoppingListController, :all_items

    # Budget
    scope "/budget" do
      resources "/sources", BudgetSourceController, except: [:new, :edit]
      resources "/entries", BudgetEntryController, except: [:new, :edit]
      get "/summary", BudgetController, :summary
    end

    # Receipts
    scope "/receipts" do
      resources "/stores", StoreController, except: [:new, :edit] do
        get "/inventory", StoreController, :get_inventory
        put "/inventory/:item_id", StoreController, :update_inventory_item
      end
      
      get "/brands/search", BrandController, :search
      resources "/brands", BrandController, except: [:new, :edit, :delete]
      
      resources "/units", UnitController, only: [:index, :create]
      
      resources "/trips", TripController, except: [:new, :edit] do
        resources "/stops", StopController, only: [:index, :create]
      end
      
      resources "/stops", StopController, only: [:update, :delete]
      
      resources "/purchases", PurchaseController, except: [:new, :edit]
      get "/purchases/suggest/brand", PurchaseController, :suggest_by_brand
      get "/purchases/suggest/item", PurchaseController, :suggest_by_item
      post "/purchases/to-inventory", PurchaseController, :add_to_inventory
      
      resources "/drivers", DriverController, only: [:index, :create]
    end

    # Notes
    resources "/notebooks", NotebookController, except: [:new, :edit] do
      resources "/pages", PageController, only: [:index, :create]
    end
    resources "/pages", PageController, only: [:show, :update, :delete]

    # Search
    get "/search", SearchController, :index

    # Tags
    get "/tags/search", TagController, :search
    post "/tags/create-tasks", TagController, :create_tasks
    resources "/tags", TagController, except: [:new, :edit] do
      get "/items", TagController, :items
    end

    # Goal Categories
    resources "/goal-categories", GoalCategoryController, except: [:new, :edit]

    # Goals
    resources "/goals", GoalController, except: [:new, :edit] do
      post "/milestones", GoalController, :create_milestone
      put "/milestones/:milestone_id", GoalController, :update_milestone
      put "/milestones/:milestone_id/toggle", GoalController, :toggle_milestone
      delete "/milestones/:milestone_id", GoalController, :delete_milestone
      put "/tags", GoalController, :update_tags
      get "/history", GoalController, :history
    end

    # Habits
    resources "/habits", HabitController, except: [:new, :edit] do
      post "/complete", HabitController, :complete
      delete "/complete", HabitController, :uncomplete
      get "/completions", HabitController, :completions
    end

    # iCal token generation
    post "/ical/token", IcalController, :generate_token

    # Export
    get "/export/all", ExportController, :export_all
    get "/export/tasks", ExportController, :export_tasks_csv
    get "/export/budget", ExportController, :export_budget_csv
    get "/export/inventory", ExportController, :export_inventory_csv

    # Notifications
    get "/notifications", NotificationController, :index
    get "/notifications/unread-count", NotificationController, :unread_count
    get "/notifications/preferences", NotificationController, :get_preferences
    put "/notifications/preferences", NotificationController, :update_preferences
    post "/notifications/mark-all-read", NotificationController, :mark_all_read
    get "/notifications/:id", NotificationController, :show
    put "/notifications/:id/read", NotificationController, :mark_read
    delete "/notifications/:id", NotificationController, :delete

    # Household management
    get "/household", HouseholdController, :show
    put "/household", HouseholdController, :update
    post "/household/invite", HouseholdController, :invite
    get "/household/invitations", HouseholdController, :list_invitations
    delete "/household/invitations/:id", HouseholdController, :cancel_invitation
    post "/household/leave", HouseholdController, :leave

    # User's received invitations (in-app)
    get "/invitations", HouseholdController, :my_invitations
    post "/invitations/:id/accept", HouseholdController, :accept_invitation
    post "/invitations/:id/decline", HouseholdController, :decline_invitation
  end

  if Application.compile_env(:mega_planner, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: MegaPlannerWeb.Telemetry
    end
  end
end
