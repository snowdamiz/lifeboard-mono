import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { UserPreferences, DashboardWidget, WidgetType, WidgetSize } from '@/types'
import { api } from '@/services/api'
import { sizeToDimensions, widgetMeta } from '@/components/dashboard/widgetConfig'
import { fetchIfStale } from '@/utils/prefetch'

// Default navigation order
const DEFAULT_NAV_ORDER = [
  'dashboard',
  'calendar',
  'goals',
  'habits',
  'inventory',
  'shopping-list',
  'budget',
  'notes',
  'reports',
  'tags',
  'settings'
]

// Default dashboard widgets with grid layout
// Row height = 10px for fine-grained control. Stat cards ~10 rows (100px), detail lists ~28 rows (280px)
const DEFAULT_WIDGETS: DashboardWidget[] = [
  { id: 'tasks_today', type: 'tasks_today', visible: true, x: 0, y: 0, w: 1, h: 10, size: 'small', minW: 1, minH: 6 },
  { id: 'inventory_status', type: 'inventory_status', visible: true, x: 1, y: 0, w: 1, h: 10, size: 'small', minW: 1, minH: 6 },
  { id: 'budget_summary', type: 'budget_summary', visible: true, x: 2, y: 0, w: 1, h: 10, size: 'small', minW: 1, minH: 6 },
  { id: 'habits_progress', type: 'habits_progress', visible: true, x: 3, y: 0, w: 1, h: 10, size: 'small', minW: 1, minH: 6 },
  { id: 'tasks_detail', type: 'tasks_detail', visible: true, x: 0, y: 10, w: 2, h: 28, size: 'large', minW: 1, minH: 12 },
  { id: 'low_inventory', type: 'low_inventory', visible: true, x: 2, y: 10, w: 2, h: 28, size: 'large', minW: 1, minH: 12 },
]

// Grid configuration - 10px rows for fine-grained resizing
export const GRID_COLS = 4
export const GRID_ROW_HEIGHT = 10
export const GRID_MARGIN = 12

export const usePreferencesStore = defineStore('preferences', () => {
  const preferences = ref<UserPreferences | null>(null)
  const loading = ref(false)
  const initialized = ref(false)

  const navOrder = computed(() => {
    if (preferences.value?.nav_order && preferences.value.nav_order.length > 0) {
      return preferences.value.nav_order
    }
    return DEFAULT_NAV_ORDER
  })

  const dashboardWidgets = computed(() => {
    if (preferences.value?.dashboard_widgets && preferences.value.dashboard_widgets.length > 0) {
      // Migrate old format if needed
      return migrateWidgets(preferences.value.dashboard_widgets)
    }
    return DEFAULT_WIDGETS
  })

  const visibleWidgets = computed(() =>
    dashboardWidgets.value.filter(w => w.visible)
  )

  const theme = computed(() => preferences.value?.theme || 'system')

  // Migrate old widget format (position-based) to new format (grid-based)
  function migrateWidgets(widgets: DashboardWidget[]): DashboardWidget[] {
    return widgets.map((w, index) => {
      // If widget already has grid properties, return as-is
      if (typeof w.x === 'number' && typeof w.y === 'number') {
        return w
      }

      // Migrate from old format
      const size = w.size || 'small'
      const dims = sizeToDimensions[size]
      const col = index % GRID_COLS
      const row = Math.floor(index / GRID_COLS) * 2 // Approximate row based on position

      return {
        ...w,
        x: col,
        y: row,
        w: dims.w,
        h: dims.h,
        size,
        minW: dims.minW,
        minH: dims.minH,
      }
    })
  }

  async function fetchPreferences() {
    return fetchIfStale('preferences', async () => {
      loading.value = true
      try {
        const response = await api.getPreferences()
        preferences.value = response.data
        initialized.value = true
      } catch (error) {
        // Use defaults if fetch fails
        console.error('Failed to fetch preferences:', error)
      } finally {
        loading.value = false
      }
    })
  }

  async function updateNavOrder(order: string[]) {
    const response = await api.updatePreferences({ nav_order: order })
    preferences.value = response.data
  }

  async function updateDashboardWidgets(widgets: DashboardWidget[]) {
    const response = await api.updatePreferences({ dashboard_widgets: widgets })
    preferences.value = response.data
  }

  async function updateTheme(newTheme: 'light' | 'dark' | 'system') {
    const response = await api.updatePreferences({ theme: newTheme })
    preferences.value = response.data
  }

  async function updateSettings(settings: Record<string, unknown>) {
    const currentSettings = preferences.value?.settings || {}
    const response = await api.updatePreferences({
      settings: { ...currentSettings, ...settings }
    })
    preferences.value = response.data
  }

  // Add a new widget with automatic positioning
  function addWidget(type: WidgetType, size: WidgetSize = 'medium') {
    const id = `${type}_${Date.now()}`
    const dims = sizeToDimensions[size]

    // Find next available position
    const { x, y } = findNextPosition(dims.w, dims.h)

    const widget: DashboardWidget = {
      id,
      type,
      visible: true,
      x,
      y,
      w: dims.w,
      h: dims.h,
      size,
      minW: dims.minW,
      minH: dims.minH,
    }

    const widgets = [...dashboardWidgets.value, widget]
    return updateDashboardWidgets(widgets)
  }

  // Find next available position for a widget
  function findNextPosition(w: number, h: number): { x: number; y: number } {
    const occupied = new Set<string>()

    // Mark occupied cells
    for (const widget of dashboardWidgets.value) {
      if (!widget.visible) continue
      for (let dx = 0; dx < widget.w; dx++) {
        for (let dy = 0; dy < widget.h; dy++) {
          occupied.add(`${widget.x + dx},${widget.y + dy}`)
        }
      }
    }

    // Find first position that fits
    for (let y = 0; y < 100; y++) {
      for (let x = 0; x <= GRID_COLS - w; x++) {
        let fits = true
        for (let dx = 0; dx < w && fits; dx++) {
          for (let dy = 0; dy < h && fits; dy++) {
            if (occupied.has(`${x + dx},${y + dy}`)) {
              fits = false
            }
          }
        }
        if (fits) return { x, y }
      }
    }

    return { x: 0, y: 0 }
  }

  function removeWidget(widgetId: string) {
    const widgets = dashboardWidgets.value.filter(w => w.id !== widgetId)
    return updateDashboardWidgets(widgets)
  }

  function toggleWidgetVisibility(widgetId: string) {
    const widgets = dashboardWidgets.value.map(w =>
      w.id === widgetId ? { ...w, visible: !w.visible } : w
    )
    return updateDashboardWidgets(widgets)
  }

  // Update widget size and recalculate grid dimensions
  function resizeWidget(widgetId: string, newSize: WidgetSize) {
    const dims = sizeToDimensions[newSize]
    const widgets = dashboardWidgets.value.map(w =>
      w.id === widgetId
        ? { ...w, size: newSize, w: dims.w, h: dims.h, minW: dims.minW, minH: dims.minH }
        : w
    )
    return updateDashboardWidgets(widgets)
  }

  // Update layout from grid-layout-plus events
  function updateLayout(layout: Array<{ i: string; x: number; y: number; w: number; h: number }>) {
    const layoutMap = new Map(layout.map(item => [item.i, item]))
    const widgets = dashboardWidgets.value.map(w => {
      const layoutItem = layoutMap.get(w.id)
      if (layoutItem) {
        return {
          ...w,
          x: layoutItem.x,
          y: layoutItem.y,
          w: layoutItem.w,
          h: layoutItem.h,
        }
      }
      return w
    })
    return updateDashboardWidgets(widgets)
  }

  // Convert widgets to grid-layout-plus format
  function getGridLayout() {
    return visibleWidgets.value.map(w => ({
      i: w.id,
      x: w.x,
      y: w.y,
      w: w.w,
      h: w.h,
      minW: w.minW || 1,
      minH: w.minH || 1,
    }))
  }

  // Get widget meta info
  function getWidgetMeta(type: WidgetType) {
    return widgetMeta.find(m => m.type === type)
  }

  // Get available widget types (not already on dashboard)
  function getAvailableWidgetTypes(): WidgetType[] {
    const usedTypes = new Set(dashboardWidgets.value.map(w => w.type))
    return widgetMeta
      .filter(m => !usedTypes.has(m.type))
      .map(m => m.type)
  }

  return {
    preferences,
    loading,
    initialized,
    navOrder,
    dashboardWidgets,
    visibleWidgets,
    theme,
    fetchPreferences,
    updateNavOrder,
    updateDashboardWidgets,
    updateTheme,
    updateSettings,
    addWidget,
    removeWidget,
    toggleWidgetVisibility,
    resizeWidget,
    updateLayout,
    getGridLayout,
    getWidgetMeta,
    getAvailableWidgetTypes,
  }
})
