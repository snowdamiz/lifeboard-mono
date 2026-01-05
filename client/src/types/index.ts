// User
export interface User {
  id: string
  email: string
  name: string | null
  avatar_url: string | null
  household_id: string
}

// Household
export interface HouseholdMember {
  id: string
  name: string | null
  email: string
  avatar_url: string | null
  joined_at: string
}

export interface Household {
  id: string
  name: string
  members: HouseholdMember[]
  inserted_at: string
  updated_at: string
}

export interface HouseholdInvitation {
  id: string
  email: string
  status: 'pending' | 'accepted' | 'declined' | 'expired'
  expires_at: string
  inviter: { id: string; name: string | null } | null
  inserted_at: string
}

// Invitation received by the user (from another household)
export interface ReceivedInvitation {
  id: string
  status: 'pending' | 'accepted' | 'declined' | 'expired'
  expires_at: string
  household: { id: string; name: string } | null
  inviter: { id: string; name: string | null; email: string } | null
  inserted_at: string
}

// Task
export interface TaskStep {
  id: string
  content: string
  completed: boolean
  position: number
}

export interface Tag {
  id: string
  name: string
  color: string
}

export interface Task {
  id: string
  title: string
  description: string | null
  date: string | null
  start_time: string | null
  duration_minutes: number | null
  priority: number
  status: 'not_started' | 'in_progress' | 'completed'
  is_recurring: boolean
  recurrence_rule: RecurrenceRule | null
  task_type: 'todo' | 'timed' | 'floating'
  parent_task_id: string | null
  steps: TaskStep[]
  tags: Tag[]
  inserted_at: string
  updated_at: string
}

export interface RecurrenceRule {
  freq: 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY'
  interval: number
  byday?: string[]
  until?: string
}

// Inventory
export interface InventorySheet {
  id: string
  name: string
  columns: Record<string, string>
  items?: InventoryItem[]
  inserted_at: string
  updated_at: string
}

export interface InventoryItem {
  id: string
  name: string
  quantity: number
  min_quantity: number
  is_necessity: boolean
  store: string | null
  unit_of_measure: string | null
  brand: string | null
  tags: Tag[]
  tag_ids?: string[] // Used when creating/updating
  custom_fields: Record<string, unknown>
  sheet_id: string
  inserted_at: string
  updated_at: string
}

export interface ShoppingList {
  id: string
  name: string
  is_auto_generated: boolean
  notes: string | null
  items: ShoppingListItem[]
  item_count: number
  unpurchased_count: number
  inserted_at: string
  updated_at: string
}

export interface ShoppingListItem {
  id: string
  name: string | null
  quantity_needed: number
  purchased: boolean
  shopping_list_id: string
  inventory_item?: {
    id: string
    name: string
    store: string | null
    sheet_name: string
  }
  inserted_at: string
}

// Budget
export interface BudgetSource {
  id: string
  name: string
  type: 'income' | 'expense'
  amount: string
  is_recurring: boolean
  recurrence_rule: RecurrenceRule | null
  tags: Tag[]
  inserted_at: string
  updated_at: string
}

export interface BudgetEntry {
  id: string
  date: string
  amount: string
  type: 'income' | 'expense'
  notes: string | null
  source_id: string | null
  source: { id: string; name: string } | null
  inserted_at: string
  updated_at: string
}

export interface BudgetSummary {
  year: number
  month: number
  income: string
  expense: string
  net: string
  savings_rate: string
  entry_count: number
}

// Notes
export interface Notebook {
  id: string
  name: string
  inserted_at: string
  updated_at: string
}

export interface PageLink {
  id: string
  link_type: 'task' | 'inventory_item' | 'budget_entry' | 'page'
  linked_id: string
}

export interface Page {
  id: string
  title: string
  content: string | null
  notebook_id: string
  links: PageLink[]
  inserted_at: string
  updated_at: string
}

// Search
export interface SearchResult {
  id: string
  type: string
  title: string
  description: string | null
  date?: string
}

export interface SearchResults {
  tasks: SearchResult[]
  inventory_items: SearchResult[]
  budget_sources: SearchResult[]
  pages: SearchResult[]
  goals: SearchResult[]
  habits: SearchResult[]
  total: number
}

// Notifications
export interface Notification {
  id: string
  type: 'task_due' | 'low_inventory' | 'budget_warning' | 'habit_reminder' | 'system'
  title: string
  message: string | null
  data: Record<string, unknown>
  read: boolean
  read_at: string | null
  link_type: 'task' | 'inventory_item' | 'budget_entry' | 'habit' | 'page' | null
  link_id: string | null
  inserted_at: string
}

export interface NotificationPreferences {
  task_due_enabled: boolean
  task_due_hours_before: number
  low_inventory_enabled: boolean
  budget_threshold_enabled: boolean
  budget_threshold_percent: number
  habit_reminder_enabled: boolean
  push_enabled: boolean
}

// Goals & Habits
export interface GoalCategory {
  id: string
  name: string
  color: string
  position: number
  parent_id: string | null
  parent?: {
    id: string
    name: string
    color: string
  } | null
  subcategories: GoalCategory[]
  inserted_at: string
  updated_at: string
}

export interface Goal {
  id: string
  title: string
  description: string | null
  target_date: string | null
  status: 'not_started' | 'in_progress' | 'completed' | 'abandoned'
  category: string | null
  goal_category_id: string | null
  goal_category?: {
    id: string
    name: string
    color: string
    parent?: {
      id: string
      name: string
      color: string
    } | null
  } | null
  progress: number
  milestones: Milestone[]
  tags: Tag[]
  linked_tasks: string[]
  inserted_at: string
  updated_at: string
}

export interface Milestone {
  id: string
  title: string
  completed: boolean
  completed_at: string | null
  position: number
}

export interface GoalHistoryItem {
  type: 'status_change' | 'milestone_completed'
  id: string
  timestamp: string
  // For status_change
  from_status?: string | null
  to_status?: string
  notes?: string | null
  user?: { id: string; name: string | null } | null
  // For milestone_completed
  title?: string
}

export interface Habit {
  id: string
  name: string
  description: string | null
  frequency: 'daily' | 'weekly'
  days_of_week: number[] | null
  reminder_time: string | null
  streak_count: number
  longest_streak: number
  color: string
  inserted_at: string
  updated_at: string
}

export interface HabitCompletion {
  id: string
  habit_id: string
  completed_at: string
}

// Task Templates
export interface TaskTemplate {
  id: string
  name: string
  description: string | null
  category: string | null
  title: string
  task_description: string | null
  duration_minutes: number | null
  priority: number
  task_type: 'todo' | 'timed' | 'floating'
  default_steps: string[]
  inserted_at: string
  updated_at: string
}

// User Preferences
export type WidgetType = 
  | 'tasks_today'
  | 'tasks_detail'
  | 'inventory_status'
  | 'low_inventory'
  | 'budget_summary'
  | 'budget_sources'
  | 'habits_progress'
  | 'active_goals'
  | 'recent_notes'
  | 'upcoming_tasks'
  | 'notifications_summary'
  | 'habit_streaks'
  | 'weekly_overview'
  | 'quick_actions'

export type WidgetSize = 'small' | 'medium' | 'large' | 'wide' | 'tall'

export interface DashboardWidget {
  id: string
  type: WidgetType
  visible: boolean
  // Grid position (vue-grid-layout format)
  x: number
  y: number
  w: number  // width in grid units
  h: number  // height in grid units
  // Preset size for easy selection
  size: WidgetSize
  // Constraints
  minW?: number
  minH?: number
  maxW?: number
  maxH?: number
}

export interface UserPreferences {
  id: string
  nav_order: string[]
  dashboard_widgets: DashboardWidget[]
  theme: 'light' | 'dark' | 'system'
  settings: Record<string, unknown>
  updated_at: string
}

// API Response
export interface ApiResponse<T> {
  data: T
}

export interface ApiError {
  error?: string
  errors?: Record<string, string[]>
}

