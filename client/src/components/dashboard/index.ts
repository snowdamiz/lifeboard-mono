export { default as WidgetWrapper } from './WidgetWrapper.vue'
export { default as WidgetPickerModal } from './WidgetPickerModal.vue'
export { default as TasksTodayWidget } from './TasksTodayWidget.vue'
export { default as TasksDetailWidget } from './TasksDetailWidget.vue'
export { default as InventoryStatusWidget } from './InventoryStatusWidget.vue'
export { default as LowInventoryWidget } from './LowInventoryWidget.vue'
export { default as BudgetSummaryWidget } from './BudgetSummaryWidget.vue'
export { default as BudgetSourcesWidget } from './BudgetSourcesWidget.vue'
export { default as HabitsProgressWidget } from './HabitsProgressWidget.vue'
export { default as ActiveGoalsWidget } from './ActiveGoalsWidget.vue'
export { default as RecentNotesWidget } from './RecentNotesWidget.vue'
export { default as UpcomingTasksWidget } from './UpcomingTasksWidget.vue'
export { default as NotificationsSummaryWidget } from './NotificationsSummaryWidget.vue'
export { default as HabitStreaksWidget } from './HabitStreaksWidget.vue'
export { default as WeeklyOverviewWidget } from './WeeklyOverviewWidget.vue'
export { default as QuickActionsWidget } from './QuickActionsWidget.vue'

// Re-export config
export { widgetMeta, sizeToDimensions, getDimensions } from './widgetConfig'
export type { WidgetMeta } from './widgetConfig'

import type { Component } from 'vue'
import type { WidgetType } from '@/types'

import TasksTodayWidget from './TasksTodayWidget.vue'
import TasksDetailWidget from './TasksDetailWidget.vue'
import InventoryStatusWidget from './InventoryStatusWidget.vue'
import LowInventoryWidget from './LowInventoryWidget.vue'
import BudgetSummaryWidget from './BudgetSummaryWidget.vue'
import BudgetSourcesWidget from './BudgetSourcesWidget.vue'
import HabitsProgressWidget from './HabitsProgressWidget.vue'
import ActiveGoalsWidget from './ActiveGoalsWidget.vue'
import RecentNotesWidget from './RecentNotesWidget.vue'
import UpcomingTasksWidget from './UpcomingTasksWidget.vue'
import NotificationsSummaryWidget from './NotificationsSummaryWidget.vue'
import HabitStreaksWidget from './HabitStreaksWidget.vue'
import WeeklyOverviewWidget from './WeeklyOverviewWidget.vue'
import QuickActionsWidget from './QuickActionsWidget.vue'

// Widget component map
export const widgetComponents: Record<WidgetType, Component> = {
  tasks_today: TasksTodayWidget,
  tasks_detail: TasksDetailWidget,
  inventory_status: InventoryStatusWidget,
  low_inventory: LowInventoryWidget,
  budget_summary: BudgetSummaryWidget,
  budget_sources: BudgetSourcesWidget,
  habits_progress: HabitsProgressWidget,
  active_goals: ActiveGoalsWidget,
  recent_notes: RecentNotesWidget,
  upcoming_tasks: UpcomingTasksWidget,
  notifications_summary: NotificationsSummaryWidget,
  habit_streaks: HabitStreaksWidget,
  weekly_overview: WeeklyOverviewWidget,
  quick_actions: QuickActionsWidget,
}
