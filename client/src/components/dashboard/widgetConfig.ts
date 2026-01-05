import type { Component } from 'vue'
import type { WidgetType, WidgetSize } from '@/types'

// Widget metadata for the picker
export interface WidgetMeta {
  type: WidgetType
  name: string
  description: string
  icon: string
  defaultSize: WidgetSize
  category: 'stats' | 'lists' | 'actions'
}

export const widgetMeta: WidgetMeta[] = [
  { type: 'tasks_today', name: "Today's Tasks", description: 'Task count and progress for today', icon: 'Calendar', defaultSize: 'small', category: 'stats' },
  { type: 'tasks_detail', name: 'Tasks List', description: 'Detailed list of today\'s tasks', icon: 'Calendar', defaultSize: 'large', category: 'lists' },
  { type: 'inventory_status', name: 'Inventory', description: 'Inventory sheets overview', icon: 'Package', defaultSize: 'small', category: 'stats' },
  { type: 'low_inventory', name: 'Low Inventory', description: 'Items running low', icon: 'AlertTriangle', defaultSize: 'large', category: 'lists' },
  { type: 'budget_summary', name: 'Monthly Net', description: 'Monthly income vs expenses', icon: 'TrendingUp', defaultSize: 'small', category: 'stats' },
  { type: 'budget_sources', name: 'Budget Sources', description: 'Income and expense sources', icon: 'DollarSign', defaultSize: 'small', category: 'stats' },
  { type: 'habits_progress', name: 'Habits Progress', description: 'Today\'s habit completion', icon: 'Flame', defaultSize: 'medium', category: 'stats' },
  { type: 'active_goals', name: 'Active Goals', description: 'Goals in progress', icon: 'Target', defaultSize: 'large', category: 'lists' },
  { type: 'recent_notes', name: 'Recent Notes', description: 'Recently edited notes', icon: 'FileText', defaultSize: 'large', category: 'lists' },
  { type: 'upcoming_tasks', name: 'Upcoming Tasks', description: 'Tasks for the next 7 days', icon: 'CalendarDays', defaultSize: 'large', category: 'lists' },
  { type: 'notifications_summary', name: 'Notifications', description: 'Recent notifications', icon: 'Bell', defaultSize: 'large', category: 'lists' },
  { type: 'habit_streaks', name: 'Habit Streaks', description: 'Top habit streaks', icon: 'Trophy', defaultSize: 'large', category: 'lists' },
  { type: 'weekly_overview', name: 'Weekly Overview', description: 'This week at a glance', icon: 'CalendarRange', defaultSize: 'wide', category: 'stats' },
  { type: 'quick_actions', name: 'Quick Actions', description: 'Quick add buttons', icon: 'Plus', defaultSize: 'medium', category: 'actions' },
]

// Size to grid dimensions mapping (row height = 10px)
// small: ~100px, medium: ~160px, large: ~280px
export const sizeToDimensions: Record<WidgetSize, { w: number; h: number; minW: number; minH: number }> = {
  small: { w: 1, h: 10, minW: 1, minH: 6 },
  medium: { w: 1, h: 16, minW: 1, minH: 8 },
  large: { w: 2, h: 28, minW: 1, minH: 12 },
  wide: { w: 2, h: 10, minW: 2, minH: 6 },
  tall: { w: 1, h: 36, minW: 1, minH: 16 },
}

// Get dimensions for a size
export function getDimensions(size: WidgetSize) {
  return sizeToDimensions[size]
}

