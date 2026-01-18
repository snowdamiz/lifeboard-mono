<script setup lang="ts">
import { onMounted, computed, ref, markRaw, watch } from 'vue'
import { format } from 'date-fns'
import { GridLayout, GridItem } from 'grid-layout-plus'
import { useDebounceFn, useMediaQuery } from '@vueuse/core'
import { 
  Clock, Settings2, Plus, X
} from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'
import { useCalendarStore } from '@/stores/calendar'
import { useInventoryStore } from '@/stores/inventory'
import { useBudgetStore } from '@/stores/budget'
import { useAuthStore } from '@/stores/auth'
import { usePreferencesStore, GRID_COLS, GRID_ROW_HEIGHT, GRID_MARGIN } from '@/stores/preferences'
import { widgetComponents, WidgetPickerModal } from '@/components/dashboard'
import type { WidgetType } from '@/types'

const calendarStore = useCalendarStore()
const inventoryStore = useInventoryStore()
const budgetStore = useBudgetStore()
const authStore = useAuthStore()
const preferencesStore = usePreferencesStore()

// Mobile detection
const isMobile = useMediaQuery('(max-width: 640px)')

// Edit mode
const isEditMode = ref(false)
const showWidgetPicker = ref(false)

// Local layout state - NOT reactive to store to avoid loops
const localLayout = ref<Array<{ i: string; x: number; y: number; w: number; h: number; minW?: number; minH?: number }>>([])

// Track if we're currently dragging
const isDragging = ref(false)

// Store original layout when entering edit mode (for cancel functionality)
const originalLayout = ref<Array<{ i: string; x: number; y: number; w: number; h: number; minW?: number; minH?: number }> | null>(null)

// Initialize layout from store
watch(() => preferencesStore.visibleWidgets, (widgets) => {
  // Only update local layout if not currently dragging
  if (!isDragging.value) {
    localLayout.value = widgets.map(w => ({
      i: w.id,
      x: w.x,
      y: w.y,
      w: w.w,
      h: w.h,
      minW: w.minW || 1,
      minH: w.minH || 1,
    }))
  }
}, { immediate: true, deep: true })

const greeting = computed(() => {
  const hour = new Date().getHours()
  if (hour < 12) return 'Good morning'
  if (hour < 18) return 'Good afternoon'
  return 'Good evening'
})

// Get widget component by ID
const getWidgetComponentById = (id: string) => {
  const widget = preferencesStore.visibleWidgets.find(w => w.id === id)
  if (widget) {
    return markRaw(widgetComponents[widget.type])
  }
  return null
}

// Check if widget is a "stat" type (small card)
const isStatWidget = (id: string) => {
  const widget = preferencesStore.visibleWidgets.find(w => w.id === id)
  if (!widget) return false
  const statTypes = ['tasks_today', 'inventory_status', 'budget_summary', 'budget_sources', 'habits_progress']
  return statTypes.includes(widget.type)
}

// Debounced save to prevent rapid API calls
const debouncedSave = useDebounceFn((newLayout: typeof localLayout.value) => {
  preferencesStore.updateLayout(newLayout)
}, 500)

// Handle drag start
const handleDragStart = () => {
  isDragging.value = true
}

// Handle drag end - just mark as not dragging, don't save yet
const handleDragEnd = () => {
  isDragging.value = false
}

// Enter edit mode - save original layout for cancel
const enterEditMode = () => {
  originalLayout.value = JSON.parse(JSON.stringify(localLayout.value))
  isEditMode.value = true
}

// Exit edit mode - save changes (Done button)
const exitEditModeSave = () => {
  preferencesStore.updateLayout(localLayout.value)
  originalLayout.value = null
  isEditMode.value = false
}

// Cancel edit mode - restore original layout (X button)
const cancelEditMode = () => {
  if (originalLayout.value) {
    localLayout.value = originalLayout.value
  }
  originalLayout.value = null
  isEditMode.value = false
}

// Handle layout change from grid (just update local state, don't save)
const handleLayoutUpdate = (newLayout: typeof localLayout.value) => {
  localLayout.value = newLayout
}

// Handle widget removal
const handleRemoveWidget = (widgetId: string) => {
  preferencesStore.removeWidget(widgetId)
}

// Handle resize end
const handleResized = () => {
  isDragging.value = false
}

// Handle add widget
const handleAddWidget = (type: WidgetType) => {
  preferencesStore.addWidget(type)
  showWidgetPicker.value = false
}

onMounted(async () => {
  await preferencesStore.fetchPreferences()
  await Promise.all([
    calendarStore.fetchTodayTasks(),
    inventoryStore.fetchSheets(),
    budgetStore.fetchSummary()
  ])
  
  // Load first sheet for low inventory check
  if (inventoryStore.sheets.length > 0) {
    await inventoryStore.fetchSheet(inventoryStore.sheets[0].id)
  }
})
</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in">
    <!-- Header -->
    <div class="flex items-end justify-between">
      <div>
        <h1 class="text-xl sm:text-2xl font-semibold tracking-tight text-balance">
          {{ greeting }}, {{ authStore.user?.name?.split(' ')[0] || 'there' }}
        </h1>
        <p class="text-muted-foreground mt-1 text-xs sm:text-sm">
          {{ format(new Date(), 'EEEE, MMMM d, yyyy') }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <Button 
          v-if="isEditMode"
          variant="outline"
          size="sm"
          @click="showWidgetPicker = true"
        >
          <Plus class="h-4 w-4 mr-1" />
          <span class="hidden sm:inline">Add Widget</span>
          <span class="sm:hidden">Add</span>
        </Button>
        <Button 
          :variant="isEditMode ? 'default' : 'ghost'"
          size="icon"
          @click="isEditMode ? cancelEditMode() : enterEditMode()"
          :title="isEditMode ? 'Cancel changes' : 'Customize dashboard'"
        >
          <X v-if="isEditMode" class="h-4 w-4" />
          <Settings2 v-else class="h-4 w-4" />
        </Button>
        <div class="hidden sm:flex items-center gap-2 text-sm text-muted-foreground">
          <Clock class="h-4 w-4" />
          {{ format(new Date(), 'h:mm a') }}
        </div>
      </div>
    </div>

    <!-- Edit mode indicator (desktop only for drag/resize info) -->
    <div 
      v-if="isEditMode" 
      class="p-3 bg-primary/5 rounded-xl border border-primary/20 flex items-center justify-between"
    >
      <div>
        <p class="text-sm font-medium">Edit Mode</p>
        <p class="text-xs text-muted-foreground">
          <span v-if="isMobile">Tap X to remove widgets</span>
          <span v-else>Drag to move, drag corners to resize</span>
        </p>
      </div>
      <Button variant="ghost" size="sm" @click="exitEditModeSave">
        Done
      </Button>
    </div>

    <!-- Mobile Layout - Simple vertical stack -->
    <div v-if="isMobile" class="space-y-3">
      <!-- Stats grid - 2 columns on mobile -->
      <div class="grid grid-cols-2 gap-3">
        <Card
          v-for="widget in preferencesStore.visibleWidgets.filter(w => isStatWidget(w.id))"
          :key="widget.id"
          class="relative overflow-hidden"
        >
          <!-- Remove button in edit mode -->
          <button
            v-if="isEditMode"
            class="absolute top-1 right-1 p-1 rounded-md bg-destructive/90 text-destructive-foreground hover:bg-destructive transition-colors z-10"
            @click="handleRemoveWidget(widget.id)"
          >
            <X class="h-3 w-3" />
          </button>
          <component 
            :is="widgetComponents[widget.type]" 
            :is-edit-mode="false"
          />
        </Card>
      </div>

      <!-- Detail widgets - full width -->
      <Card
        v-for="widget in preferencesStore.visibleWidgets.filter(w => !isStatWidget(w.id))"
        :key="widget.id"
        class="relative overflow-hidden"
      >
        <!-- Remove button in edit mode -->
        <button
          v-if="isEditMode"
          class="absolute top-1 right-1 p-1 rounded-md bg-destructive/90 text-destructive-foreground hover:bg-destructive transition-colors z-10"
          @click="handleRemoveWidget(widget.id)"
        >
          <X class="h-3 w-3" />
        </button>
        <component 
          :is="widgetComponents[widget.type]" 
          :is-edit-mode="false"
        />
      </Card>

      <!-- Empty state -->
      <div 
        v-if="preferencesStore.visibleWidgets.length === 0" 
        class="text-center py-6 px-4"
      >
        <div class="h-10 w-10 rounded-xl bg-primary/10 mx-auto mb-2 flex items-center justify-center">
          <Settings2 class="h-5 w-5 text-primary/60" />
        </div>
        <h3 class="font-medium text-sm">No widgets</h3>
        <p class="text-muted-foreground text-xs mt-0.5 mb-3">Add widgets to your dashboard</p>
        <Button size="sm" class="h-7 text-xs" @click="showWidgetPicker = true">
          <Plus class="h-3.5 w-3.5 mr-1" />
          Add Widget
        </Button>
      </div>
    </div>

    <!-- Desktop Grid Layout -->
    <GridLayout
      v-else
      :layout="localLayout"
      :col-num="GRID_COLS"
      :row-height="GRID_ROW_HEIGHT"
      :margin="[GRID_MARGIN, GRID_MARGIN]"
      :is-draggable="isEditMode"
      :is-resizable="isEditMode"
      :vertical-compact="true"
      :use-css-transforms="true"
      :responsive="true"
      :breakpoints="{ lg: 1200, md: 996, sm: 768, xs: 640, xxs: 0 }"
      :cols="{ lg: 4, md: 3, sm: 2, xs: 2, xxs: 1 }"
      @layout-updated="handleLayoutUpdate"
    >
      <GridItem
        v-for="item in localLayout"
        :key="item.i"
        :i="item.i"
        :x="item.x"
        :y="item.y"
        :w="item.w"
        :h="item.h"
        :min-w="item.minW || 1"
        :min-h="item.minH || 1"
        class="transition-shadow"
        :class="isEditMode && 'ring-2 ring-primary/20 ring-offset-2 ring-offset-background rounded-xl'"
        @move="handleDragStart"
        @moved="handleDragEnd"
        @resize="handleDragStart"
        @resized="handleResized"
      >
        <Card class="h-full w-full overflow-hidden relative">
          <!-- Edit mode controls -->
          <div v-if="isEditMode" class="absolute inset-0 z-10 pointer-events-none">
            <!-- Drag handle indicator -->
            <div class="absolute top-0 left-0 right-0 h-6 bg-primary/5 border-b border-primary/20 flex items-center justify-center pointer-events-auto cursor-move">
              <div class="flex gap-1">
                <div class="w-1 h-1 rounded-full bg-primary/40" />
                <div class="w-1 h-1 rounded-full bg-primary/40" />
                <div class="w-1 h-1 rounded-full bg-primary/40" />
              </div>
            </div>
            
            <!-- Remove button -->
            <button
              class="absolute top-0.5 right-0.5 p-1 rounded-md bg-destructive/90 text-destructive-foreground hover:bg-destructive transition-colors pointer-events-auto z-20"
              @click.stop="handleRemoveWidget(item.i)"
              title="Remove widget"
            >
              <X class="h-3 w-3" />
            </button>
          </div>

          <!-- Widget content -->
          <div :class="['h-full overflow-auto', isEditMode && 'pt-6']">
            <component 
              :is="getWidgetComponentById(item.i)" 
              :is-edit-mode="isEditMode"
            />
          </div>
        </Card>
      </GridItem>
    </GridLayout>

    <!-- Desktop Empty state -->
    <div 
      v-if="!isMobile && localLayout.length === 0" 
      class="text-center py-8 px-4"
    >
      <div class="h-12 w-12 rounded-xl bg-primary/10 mx-auto mb-3 flex items-center justify-center">
        <Settings2 class="h-6 w-6 text-primary/60" />
      </div>
      <h3 class="font-medium text-base">No widgets on your dashboard</h3>
      <p class="text-muted-foreground text-sm mt-1 mb-3">Add widgets to customize your dashboard</p>
      <Button size="sm" @click="showWidgetPicker = true">
        <Plus class="h-4 w-4 mr-1" />
        Add Widget
      </Button>
    </div>

    <!-- Widget Picker Modal -->
    <WidgetPickerModal
      v-model:open="showWidgetPicker"
      @add="handleAddWidget"
    />
  </div>
</template>

<style>
/* Grid layout styles */
.vue-grid-layout {
  min-height: 200px;
}

.vue-grid-item {
  transition: transform 200ms ease;
}

.vue-grid-item.vue-grid-placeholder {
  background: hsl(var(--primary) / 0.1);
  border: 2px dashed hsl(var(--primary) / 0.3);
  border-radius: var(--radius);
}

.vue-grid-item.resizing {
  opacity: 0.9;
}

.vue-grid-item.vue-draggable-dragging {
  transition: none;
  z-index: 50;
  opacity: 0.9;
}

/* Resize handle - only visible in edit mode */
.vue-grid-item > .vue-resizable-handle {
  position: absolute;
  width: 20px;
  height: 20px;
  bottom: 0;
  right: 0;
  cursor: se-resize;
  background: transparent;
  z-index: 20;
}

.vue-grid-item > .vue-resizable-handle::after {
  content: '';
  position: absolute;
  right: 4px;
  bottom: 4px;
  width: 8px;
  height: 8px;
  border-right: 2px solid hsl(var(--primary) / 0.5);
  border-bottom: 2px solid hsl(var(--primary) / 0.5);
  border-radius: 0 0 2px 0;
}

/* Drag handle */
.drag-handle {
  cursor: move;
}
</style>
