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
  task_type: 'todo' | 'timed' | 'floating' | 'trip'
  parent_task_id: string | null
  trip_id: string | null
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
  tags?: Tag[]
  tag_ids?: string[]
  inserted_at: string
  updated_at: string
}

export interface InventoryItem {
  id: string
  name: string
  quantity: string | number
  min_quantity: string | number
  is_necessity: boolean
  store: string | null
  unit_of_measure: string | null
  brand: string | null
  count: string | null
  count_unit: string | null
  price_per_count: string | null
  price_per_unit: string | null
  taxable: boolean | null
  total_price: string | null
  store_code: string | null
  item_name: string | null
  // "count" = consumed per container (1 box, 1 pack)
  // "quantity" = consumed by weight/volume (7 lbs, 16 oz)
  usage_mode?: 'count' | 'quantity'
  tags: Tag[]
  tag_ids?: string[] // Used when creating/updating
  custom_fields: Record<string, unknown>
  sheet_id: string
  // Trip/Purchase linkage for data parity with calendar
  trip_id: string | null
  stop_id: string | null
  purchase_id: string | null
  purchase_date: string | null
  inserted_at: string
  updated_at: string
}

export interface ShoppingList {
  id: string
  name: string
  is_auto_generated: boolean
  status: 'active' | 'completed'
  notes: string | null
  items: ShoppingListItem[]
  item_count: number
  unpurchased_count: number
  completed_count: number
  tags?: Tag[]
  tag_ids?: string[]
  inserted_at: string
  updated_at: string
}

export interface ShoppingListItem {
  id: string
  name: string | null
  quantity_needed: number
  purchased: boolean
  completed_at: string | null
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
  tags?: Tag[]
  tag_ids?: string[]
  inserted_at: string
  updated_at: string
  is_trip?: boolean
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

// Receipts
export interface Store {
  id: string
  name: string
  address: string | null
  state: string | null
  store_code: string | null
  tax_rate: string | null
  image_url: string | null
  inserted_at: string
  updated_at: string
}

export interface Stop {
  id: string
  trip_id: string
  store_id: string | null
  store_name: string | null
  store_address: string | null
  notes: string | null
  position: number
  time_arrived: string | null
  time_left: string | null
  purchases?: Purchase[]
  inserted_at: string
}

export interface Driver {
  id: string
  name: string
  household_id: string
  inserted_at: string
  updated_at: string
}

export interface Trip {
  id: string
  driver: string | null
  driver_id: string | null
  trip_start: string | null
  trip_end: string | null
  notes: string | null
  stops: Stop[]
  inserted_at: string
  updated_at: string
}

export interface Brand {
  id: string
  name: string
  default_item: string | null
  default_unit_measurement: string | null
  default_tags: string[]
  image_url: string | null
  inserted_at: string
  updated_at: string
}

export interface Unit {
  id: string
  name: string
  household_id: string
  inserted_at: string
  updated_at: string
}

export interface Purchase {
  id: string
  stop_id: string | null
  budget_entry_id: string
  brand: string
  item: string
  unit_measurement: string | null
  count: string | null
  count_unit: string | null
  price_per_count: string | null
  units: string | null
  price_per_unit: string | null
  taxable: boolean
  tax_rate: string | null
  total_price: string
  store_code: string | null
  item_name: string | null
  usage_mode?: 'count' | 'quantity'
  tags: Tag[]
  tag_ids?: string[]
  inserted_at: string
  updated_at: string
}

// Trip Receipt (grouped inventory items from shopping trips)
export interface TripReceipt {
  id: string
  trip_id: string | null
  store_name: string
  trip_start: string | null
  date: string | null
  items: InventoryItem[]
}

export interface BrandSuggestion {
  brand: Brand | { name: string } | null
  recent_purchases: Purchase[]
}

// Receipt Scanning
export interface ReceiptScanStore {
  name: string | null
  address: string | null
  city: string | null
  state: string | null
  store_code: string | null
  phone: string | null
  is_new?: boolean
  id?: string | null
}

export interface ReceiptScanTransaction {
  date: string | null
  time: string | null
  subtotal: string | null
  tax: string | null
  total: string | null
  payment_method: string | null
}

export interface ReceiptScanItem {
  raw_text: string | null
  brand: string
  item: string
  quantity: number
  count_unit: string | null
  unit: string | null
  unit_quantity: string | null
  unit_price: string | null
  total_price: string | null
  taxable: boolean
  tax_indicator: string | null
  tax_amount: string | null
  tax_rate: string | null
  store_code: string | null
  brand_is_new?: boolean
  brand_id?: string | null
  unit_is_new?: boolean
  unit_id?: string | null
  usage_mode?: 'count' | 'quantity'
}

export interface ReceiptScanResult {
  store: ReceiptScanStore
  transaction: ReceiptScanTransaction
  items: ReceiptScanItem[]
}

// Notes
export interface Notebook {
  id: string
  name: string
  tags?: Tag[]
  tag_ids?: string[]
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
  metadata: string | null
  notebook_id: string
  links: PageLink[]
  tags: Tag[]
  tag_ids?: string[]
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

export interface HabitInventory {
  id: string
  name: string
  color: string
  position: number
  coverage_mode: 'whole_day' | 'partial_day'
  linked_inventory_ids: string[]
  day_start_time: string | null
  day_end_time: string | null
  inserted_at: string
  updated_at: string
}

export interface Habit {
  id: string
  name: string
  description: string | null
  frequency: 'daily' | 'weekly'
  days_of_week: number[] | null
  reminder_time: string | null
  scheduled_time: string | null
  duration_minutes: number | null
  streak_count: number
  longest_streak: number
  color: string
  is_start_of_day: boolean
  inventory_id: string | null
  tags: Tag[]
  inserted_at: string
  updated_at: string
}

export interface HabitCompletion {
  id: string
  habit_id: string
  date: string
  completed_at: string
  status: 'completed' | 'skipped'
  not_today_reason: string | null
}

export interface HabitAnalytics {
  total_entries: number
  completed_count: number
  skipped_count: number
  completion_rate: number
  completions_by_day: {
    date: string
    completed: number
    skipped: number
    total: number
    completion_rate: number
  }[]
  skip_reasons: {
    reason: string
    count: number
  }[]
  habits_per_day: {
    date: string
    count: number
  }[]
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
  task_type: 'todo' | 'timed' | 'floating' | 'trip'
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

