<script setup lang="ts">
import { onMounted, onUnmounted, ref, computed, watch } from 'vue'
import { format, isToday, isSameDay, isSameMonth, addDays } from 'date-fns'
import { ChevronLeft, ChevronRight, Plus, Calendar, CalendarDays, X, Sun, ListChecks, ShoppingCart, Clock } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { useCalendarStore } from '@/stores/calendar'
import { useReceiptsStore } from '@/stores/receipts'
import TaskCard from '@/components/calendar/TaskCard.vue'
import TripCard from '@/components/calendar/TripCard.vue'
import TaskForm from '@/components/calendar/TaskForm.vue'
import TaskDetailPopout from '@/components/calendar/TaskDetailPopout.vue'
import { cn } from '@/lib/utils'
import type { Task } from '@/types'

const calendarStore = useCalendarStore()
const receiptsStore = useReceiptsStore()
const showTaskForm = ref(false)
const selectedDate = ref<Date | null>(null)
const selectedTask = ref<Task | null>(null)
const mobileSelectedDay = ref<Date>(new Date())
const expandedDay = ref<string | null>(null) // Stores ISO string of expanded day in month view
const showExpandedDayView = ref(false) // Full-screen expanded day view triggered by Today button
const expandedDayDate = ref<Date>(new Date()) // The date for expanded day view

// Inline popout editing state for weekly view
const editingTask = ref<Task | null>(null)
const editingDayIndex = ref<number | null>(null)

const handleEditTask = (task: Task, dayIndex: number) => {
  editingTask.value = task
  editingDayIndex.value = dayIndex
}

const closeEditPopout = () => {
  editingTask.value = null
  editingDayIndex.value = null
}

// Trip detail inline state (shown in the week grid like edit popout)
const showInlineTripDetail = ref(false)
const selectedTripId = ref<string | null>(null)

// Mobile detection for fallback modal
const isMobile = ref(false)
const checkMobile = () => {
  isMobile.value = window.innerWidth < 768 // md breakpoint
}

// Filtering Logic
const showFilterDropdown = ref(false)
const filterCheckedTagIds = ref<Set<string>>(new Set(calendarStore.filterTags))
const filterAppliedTagIds = computed(() => new Set<string>()) // No "applied" tags concept for filter, just selection

// Watch for store filter changes (in case changed elsewhere)
watch(() => calendarStore.filterTags, (newTags) => {
  filterCheckedTagIds.value = new Set(newTags)
})

const syncMobileSelectedDay = () => {
  const today = new Date()
  if (calendarStore.viewMode === 'month') {
    // In month view, default to today if it's in the current month, otherwise first of month
    mobileSelectedDay.value = isSameMonth(today, calendarStore.currentDate) ? today : calendarStore.monthStart
  } else {
    const isInWeek = calendarStore.weekDays.some(day => isSameDay(day, today))
    mobileSelectedDay.value = isInWeek ? today : calendarStore.weekDays[0]
  }
}

onMounted(() => {
  calendarStore.fetchCurrentViewTasks()
  syncMobileSelectedDay()
})

// Sync mobile selected day and fetch tasks when view or period changes
watch(() => calendarStore.weekStart, () => {
  if (calendarStore.viewMode === 'week') {
    calendarStore.fetchWeekTasks()
    syncMobileSelectedDay()
  }
})

watch(() => calendarStore.monthStart, () => {
  if (calendarStore.viewMode === 'month') {
    calendarStore.fetchMonthTasks()
    syncMobileSelectedDay()
  }
})

const toggleViewMode = () => {
  const newMode = calendarStore.viewMode === 'week' ? 'month' : 'week'
  calendarStore.setViewMode(newMode)
  calendarStore.fetchCurrentViewTasks()
  syncMobileSelectedDay()
}

// Header text based on view mode
const headerText = computed(() => {
  if (showExpandedDayView.value) {
    return format(expandedDayDate.value, 'EEEE, MMMM d, yyyy')
  }
  if (calendarStore.viewMode === 'month') {
    return format(calendarStore.currentDate, 'MMMM yyyy')
  }
  return `${format(calendarStore.weekStart, 'MMMM d')} – ${format(calendarStore.weekEnd, 'MMMM d, yyyy')}`
})

// Expanded day view computed properties
const expandedDayKey = computed(() => format(expandedDayDate.value, 'yyyy-MM-dd'))
const expandedDayTasks = computed(() => calendarStore.tasksByDate[expandedDayKey.value] || [])
const expandedDayTrips = computed(() => calendarStore.tripsByDate[expandedDayKey.value] || [])

// Cache for trips fetched by ID (for tasks with trip_id that reference trips not in current day)
const tripCache = ref<Record<string, any>>({})
const fetchingTripIds = ref<Set<string>>(new Set())

// Helper to get trip for a task by trip_id - checks both expandedDayTrips and cache
const getTripForTask = (tripId: string) => {
  // First check expandedDayTrips (trips for the current day)
  const dayTrip = expandedDayTrips.value.find((trip: any) => trip.id === tripId)
  if (dayTrip) return dayTrip
  
  // Otherwise check the cache
  return tripCache.value[tripId]
}

// Helper to get trip for a task from tripsByDate (for week/month views)
const getTripByIdFromDate = (tripId: string, dateKey: string) => {
  const trips = calendarStore.tripsByDate[dateKey] || []
  return trips.find((trip: any) => trip.id === tripId)
}

// Fetch trips for tasks with trip_id when expanded day tasks change
watch(expandedDayTasks, async (tasks) => {
  for (const task of tasks) {
    if (task.trip_id && !getTripForTask(task.trip_id) && !fetchingTripIds.value.has(task.trip_id)) {
      fetchingTripIds.value.add(task.trip_id)
      try {
        const trip = await receiptsStore.fetchTrip(task.trip_id)
        if (trip) {
          tripCache.value[task.trip_id] = trip
        }
      } catch (error) {
        console.error('Failed to fetch trip:', task.trip_id, error)
      } finally {
        fetchingTripIds.value.delete(task.trip_id)
      }
    }
  }
}, { immediate: true })



// Handle Today button click - toggle expanded day view
const handleTodayClick = () => {
  const today = new Date()
  expandedDayDate.value = today
  showExpandedDayView.value = true
  // Also set the calendar date so data is fetched
  calendarStore.goToToday()
  calendarStore.fetchCurrentViewTasks()
}

// Navigate to previous/next day in expanded view
const goToPrevDay = () => {
  expandedDayDate.value = addDays(expandedDayDate.value, -1)
  // Refresh data if needed (change week/month if date is outside current range)
  calendarStore.setCurrentDate(expandedDayDate.value)
  calendarStore.fetchCurrentViewTasks()
}

const goToNextDay = () => {
  expandedDayDate.value = addDays(expandedDayDate.value, 1)
  calendarStore.setCurrentDate(expandedDayDate.value)
  calendarStore.fetchCurrentViewTasks()
}

// Close expanded day view and return to week view
const closeExpandedDayView = () => {
  showExpandedDayView.value = false
}

const mobileSelectedDayTasks = computed(() => {
  const dateKey = format(mobileSelectedDay.value, 'yyyy-MM-dd')
  return calendarStore.tasksByDate[dateKey] || []
})

const dayHasTasks = (day: Date) => {
  const dateKey = format(day, 'yyyy-MM-dd')
  const tasks = calendarStore.tasksByDate[dateKey]
  return tasks && tasks.length > 0
}

const getTaskCount = (day: Date) => {
  const dateKey = format(day, 'yyyy-MM-dd')
  const tasks = calendarStore.tasksByDate[dateKey]
  return tasks ? tasks.length : 0
}

const selectMobileDay = (day: Date) => {
  mobileSelectedDay.value = day
}

// Get days for mobile view based on view mode
const mobileDays = computed(() => {
  return calendarStore.viewMode === 'month' ? calendarStore.monthDays : calendarStore.weekDays
})

// For month mobile view, get the current week containing selected day
const mobileMonthWeeks = computed(() => {
  const weeks: Date[][] = []
  for (let i = 0; i < calendarStore.monthDays.length; i += 7) {
    weeks.push(calendarStore.monthDays.slice(i, i + 7))
  }
  return weeks
})

const openNewTask = (date?: Date) => {
  selectedTask.value = null
  selectedDate.value = date || mobileSelectedDay.value || new Date()
  showTaskForm.value = true
}

const openEditTask = (task: Task, date: Date, dayIndex?: number) => {
  // In week view on desktop, use inline full-width popout
  if (calendarStore.viewMode === 'week' && !isMobile.value) {
    editingTask.value = task
    editingDayIndex.value = dayIndex ?? 0
    return
  }
  
  // Otherwise use modal (mobile, month view, etc.)
  selectedTask.value = task
  selectedDate.value = date
  showTaskForm.value = true
}

const closeTaskForm = () => {
  showTaskForm.value = false
  selectedDate.value = null
  selectedTask.value = null
}

const handleOpenTripDetail = (tripId: string) => {
  if (!tripId) return
  selectedTripId.value = tripId
  showInlineTripDetail.value = true
  // Keep editingTask open so user can return to edit after closing trip
}

const closeTripDetailModal = () => {
  showInlineTripDetail.value = false
  selectedTripId.value = null
}

const handleDeleteTrip = async (tripId: string) => {
  if (!tripId) return
  await receiptsStore.deleteTrip(tripId)
  calendarStore.fetchCurrentViewTasks()
}

import TagManager from '@/components/shared/TagManager.vue'
import TripDetailModal from '@/components/calendar/TripDetailModal.vue'
import { Filter } from 'lucide-vue-next'
import { Badge } from '@/components/ui/badge'

const applyFilters = () => {
  calendarStore.filterTags = Array.from(filterCheckedTagIds.value)
  calendarStore.fetchCurrentViewTasks()
  showFilterDropdown.value = false
}

const clearFilters = () => {
  calendarStore.filterTags = []
  filterCheckedTagIds.value = new Set()
  calendarStore.fetchCurrentViewTasks()
  showFilterDropdown.value = false
}

const toggleExpandedDay = (day: Date) => {
  const dateKey = format(day, 'yyyy-MM-dd')
  if (expandedDay.value === dateKey) {
    expandedDay.value = null
  } else {
    expandedDay.value = dateKey
  }
}

const activeFilterCount = computed(() => calendarStore.filterTags.length)

// Initialize mobile detection on mount
onMounted(() => {
  checkMobile()
  window.addEventListener('resize', checkMobile)
})

onUnmounted(() => {
  window.removeEventListener('resize', checkMobile)
})
</script>

<template>
  <div class="h-[calc(100vh-170px)] flex flex-col animate-fade-in relative overflow-hidden">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-5">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <CalendarDays class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Calendar</h1>
          <p class="text-muted-foreground text-sm mt-0.5">{{ headerText }}</p>
        </div>
      </div>

      <div class="flex items-center gap-2 sm:gap-3">
        <!-- Today Button -->
        <Button 
          :variant="showExpandedDayView && isToday(expandedDayDate) ? 'default' : 'outline'" 
          size="sm" 
          class="h-9 px-3 text-[13px] gap-1.5" 
          @click="handleTodayClick"
        >
          <Sun class="h-4 w-4" />
          Today
        </Button>

        <!-- Navigation with View Toggle -->
        <div class="flex items-center rounded-lg border border-border bg-card overflow-hidden">
          <Button variant="ghost" size="icon" class="rounded-none h-9 w-9" @click="calendarStore.prevPeriod" title="Previous">
            <ChevronLeft class="h-4 w-4" />
          </Button>
          <div class="w-px h-5 bg-border" />
          <Button 
            :variant="calendarStore.viewMode === 'week' && !showExpandedDayView ? 'default' : 'ghost'" 
            size="sm" 
            class="rounded-none h-9 px-3 gap-1.5"
            @click="showExpandedDayView = false; calendarStore.viewMode !== 'week' && toggleViewMode()"
          >
            <Calendar class="h-4 w-4" />
            <span class="hidden sm:inline text-[13px]">Week</span>
          </Button>
          <div class="w-px h-5 bg-border" />
          <Button 
            :variant="calendarStore.viewMode === 'month' && !showExpandedDayView ? 'default' : 'ghost'" 
            size="sm" 
            class="rounded-none h-9 px-3 gap-1.5"
            @click="showExpandedDayView = false; calendarStore.viewMode !== 'month' && toggleViewMode()"
          >
            <CalendarDays class="h-4 w-4" />
            <span class="hidden sm:inline text-[13px]">Month</span>
          </Button>
          <div class="w-px h-5 bg-border" />
          <Button variant="ghost" size="icon" class="rounded-none h-9 w-9" @click="calendarStore.nextPeriod" title="Next">
            <ChevronRight class="h-4 w-4" />
          </Button>
        </div>

        <!-- Filter Button -->
        <div class="relative">
          <Button 
            :variant="activeFilterCount > 0 ? 'default' : 'outline'" 
            size="sm" 
            class="h-9 gap-2"
            @click="showFilterDropdown = !showFilterDropdown"
          >
            <Filter class="h-4 w-4" />
            <span class="hidden sm:inline">Filter</span>
            <Badge v-if="activeFilterCount > 0" variant="secondary" class="ml-0.5 h-5 px-1.5 min-w-[20px] justify-center bg-background/20 text-current border-0">
              {{ activeFilterCount }}
            </Badge>
          </Button>

          <!-- Filter Dropdown -->
          <div
            v-if="showFilterDropdown"
            class="absolute top-full right-0 mt-2 w-72 bg-card border border-border rounded-xl shadow-xl z-50 overflow-hidden"
          >
            <div class="p-3 border-b border-border bg-secondary/30 flex items-center justify-between">
              <span class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Filter by Tags</span>
              <button class="text-xs text-primary hover:underline" @click="clearFilters" v-if="activeFilterCount > 0">
                Clear all
              </button>
            </div>
            
            <TagManager
              ref="filterTagManagerRef"
              v-model:checkedTagIds="filterCheckedTagIds"
              :hide-input="true"
              :compact="true"
              :embedded="true"
              :applied-tag-ids="filterAppliedTagIds"
              class="max-h-[300px] overflow-auto"
            >
              <template #actions="{ checkedCount }">
                <Button
                  type="button"
                  size="sm"
                  class="w-full text-xs"
                  @click="applyFilters"
                >
                  Apply Filter
                </Button>
              </template>
            </TagManager>
          </div>
          <!-- Backdrop to close -->
          <div v-if="showFilterDropdown" class="fixed inset-0 z-40 bg-transparent" @click="showFilterDropdown = false" />
        </div>
        
        <Button @click="openNewTask()" class="shrink-0" data-testid="add-button">
          <Plus class="h-4 w-4" />
          <span class="hidden sm:inline">New Task</span>
        </Button>
      </div>
    </div>

    <!-- Mobile Day Picker - Week View -->
    <div v-if="calendarStore.viewMode === 'week'" class="md:hidden mb-4">
      <div class="flex gap-1">
        <button
          v-for="day in calendarStore.weekDays"
          :key="day.toISOString()"
          :class="cn(
            'relative flex-1 flex flex-col items-center justify-center min-w-0 h-14 rounded-xl transition-all',
            isSameDay(day, mobileSelectedDay)
              ? 'bg-primary text-primary-foreground shadow-md shadow-primary/25'
              : isToday(day)
                ? 'bg-primary/10 text-primary'
                : 'bg-card border border-border/60 text-foreground hover:bg-secondary'
          )"
          @click="selectMobileDay(day)"
        >
          <span class="text-[10px] font-medium uppercase tracking-wider opacity-80">
            {{ format(day, 'EEE') }}
          </span>
          <span class="text-lg font-semibold mt-0.5">
            {{ format(day, 'd') }}
          </span>
          <!-- Task indicator dot -->
          <span 
            v-if="dayHasTasks(day)"
            :class="cn(
              'absolute bottom-1.5 h-1.5 w-1.5 rounded-full',
              isSameDay(day, mobileSelectedDay)
                ? 'bg-primary-foreground'
                : 'bg-primary'
            )"
          />
        </button>
      </div>
    </div>

    <!-- Mobile Month Grid -->
    <div v-if="calendarStore.viewMode === 'month'" class="md:hidden mb-4">
      <!-- Day of week headers -->
      <div class="grid grid-cols-7 mb-2">
        <div v-for="dayName in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']" :key="dayName" class="text-center text-[10px] font-medium text-muted-foreground uppercase">
          {{ dayName }}
        </div>
      </div>
      <!-- Month grid -->
      <div class="grid grid-cols-7 gap-1">
        <button
          v-for="day in calendarStore.monthDays"
          :key="day.toISOString()"
          :class="cn(
            'relative aspect-square flex flex-col items-center justify-center rounded-lg transition-all text-sm',
            isSameDay(day, mobileSelectedDay)
              ? 'bg-primary text-primary-foreground shadow-md shadow-primary/25'
              : isToday(day)
                ? 'bg-primary/10 text-primary font-semibold'
                : !isSameMonth(day, calendarStore.currentDate)
                  ? 'text-muted-foreground/40'
                  : 'text-foreground hover:bg-secondary'
          )"
          @click="selectMobileDay(day)"
        >
          <span>{{ format(day, 'd') }}</span>
          <!-- Task indicator dot -->
          <span 
            v-if="dayHasTasks(day)"
            :class="cn(
              'absolute bottom-1 h-1 w-1 rounded-full',
              isSameDay(day, mobileSelectedDay)
                ? 'bg-primary-foreground'
                : 'bg-primary'
            )"
          />
        </button>
      </div>
    </div>

    <!-- Mobile Single Day View -->
    <div class="md:hidden flex-1 flex flex-col min-h-0">
      <div class="flex items-center justify-between mb-3">
        <h2 class="text-base font-medium">
          {{ format(mobileSelectedDay, 'EEEE, MMMM d') }}
        </h2>
        <span class="text-sm text-muted-foreground">
          {{ mobileSelectedDayTasks.length }} {{ mobileSelectedDayTasks.length === 1 ? 'task' : 'tasks' }}
        </span>
      </div>
      
      <div class="flex-1 overflow-auto space-y-2 pb-4">
        <TaskCard
          v-for="task in mobileSelectedDayTasks"
          :key="task.id"
          :task="task"
          :trip="task.trip_id ? getTripByIdFromDate(task.trip_id, format(mobileSelectedDay, 'yyyy-MM-dd')) : null"
          class="!p-3"
          @manage-trip="handleOpenTripDetail"
        />

        <div 
          v-if="mobileSelectedDayTasks.length === 0" 
          class="flex flex-col items-center justify-center py-12 text-center"
        >
          <p class="text-sm text-muted-foreground mb-3">No tasks for this day</p>
          <Button size="sm" variant="outline" @click="openNewTask(mobileSelectedDay)">
            <Plus class="h-4 w-4" />
            Add Task
          </Button>
        </div>

        <button
          v-else
          class="w-full p-3 border border-dashed border-border/60 rounded-xl text-muted-foreground/60 hover:border-primary/40 hover:text-primary hover:bg-primary/5 transition-all flex items-center justify-center gap-2"
          @click="openNewTask(mobileSelectedDay)"
        >
          <Plus class="h-4 w-4" />
          <span class="text-sm">Add task</span>
        </button>
      </div>
    </div>

    <!-- Expanded Day View (Full-width detailed view) -->
    <div v-if="showExpandedDayView" class="hidden md:flex flex-1 min-h-0 flex-col rounded-xl border border-white/[0.08] bg-gradient-to-br from-card to-card/95 overflow-hidden shadow-lg shadow-black/5">
      <!-- Day Header -->
      <div class="flex items-center justify-between px-6 py-4 bg-gradient-to-b from-white/[0.04] to-transparent border-b border-border">
        <div class="flex items-center gap-4">
          <Button variant="ghost" size="icon" class="h-9 w-9" @click="goToPrevDay">
            <ChevronLeft class="h-5 w-5" />
          </Button>
          <div class="text-center">
            <h2 class="text-2xl font-bold tracking-tight">
              {{ format(expandedDayDate, 'EEEE') }}
            </h2>
            <p class="text-sm text-muted-foreground mt-0.5">
              {{ format(expandedDayDate, 'MMMM d, yyyy') }}
              <span v-if="isToday(expandedDayDate)" class="ml-2 px-2 py-0.5 bg-primary/20 text-primary text-xs font-medium rounded-full">
                Today
              </span>
            </p>
          </div>
          <Button variant="ghost" size="icon" class="h-9 w-9" @click="goToNextDay">
            <ChevronRight class="h-5 w-5" />
          </Button>
        </div>

        <div class="flex items-center gap-2">
          <Button variant="outline" size="sm" @click="openNewTask(expandedDayDate)">
            <Plus class="h-4 w-4 mr-1.5" />
            Add Task
          </Button>
          <Button variant="ghost" size="icon" @click="closeExpandedDayView">
            <X class="h-4 w-4" />
          </Button>
        </div>
      </div>

      <!-- Day Content - Single Column Layout with Trip Details Under Tasks -->
      <div class="flex-1 overflow-auto p-6">
        <div class="max-w-4xl mx-auto space-y-4">
          <h3 class="text-lg font-semibold flex items-center gap-2">
            <ListChecks class="h-5 w-5 text-primary" />
            Tasks ({{ expandedDayTasks.length }})
          </h3>
          
          <div v-if="expandedDayTasks.length === 0" class="text-center py-12 text-muted-foreground">
            <p class="text-sm">No tasks scheduled for this day</p>
            <Button variant="outline" size="sm" class="mt-3" @click="openNewTask(expandedDayDate)">
              <Plus class="h-4 w-4 mr-1.5" />
              Add Task
            </Button>
          </div>
          
          <div v-else class="space-y-4">
            <div 
              v-for="task in expandedDayTasks" 
              :key="task.id"
              class="rounded-xl border border-white/[0.08] bg-white/[0.02] overflow-hidden"
            >
              <!-- Task Header -->
              <div 
                class="p-4 hover:bg-white/[0.04] transition-all cursor-pointer"
                @click="handleEditTask(task, 0)"
              >
                <div class="flex items-start gap-3">
                  <div :class="[
                    'h-3 w-3 rounded-full mt-1.5 shrink-0',
                    task.status === 'completed' ? 'bg-emerald-500' : 
                    task.status === 'in_progress' ? 'bg-amber-500' : 
                    task.priority === 1 ? 'bg-rose-500' :
                    task.priority === 2 ? 'bg-orange-400' : 'bg-primary'
                  ]" />
                  <div class="flex-1 min-w-0">
                    <h4 :class="[
                      'font-medium',
                      task.status === 'completed' ? 'line-through text-muted-foreground' : ''
                    ]">{{ task.title }}</h4>
                    <p v-if="task.description" class="text-sm text-muted-foreground mt-1 line-clamp-2">
                      {{ task.description }}
                    </p>
                    <div class="flex items-center gap-3 mt-2 text-xs text-muted-foreground">
                      <span v-if="task.start_time" class="flex items-center gap-1">
                        <Clock class="h-3.5 w-3.5" />
                        {{ task.start_time?.slice(0, 5) }}
                      </span>
                      <span v-if="task.duration_minutes">{{ task.duration_minutes }}min</span>
                      <span v-if="task.task_type === 'trip'" class="px-2 py-0.5 bg-emerald-500/20 text-emerald-500 rounded-full">
                        Trip
                      </span>
                    </div>
                    <!-- Task Steps -->
                    <div v-if="task.steps?.length > 0" class="mt-3 space-y-1">
                      <div 
                        v-for="step in task.steps" 
                        :key="step.id"
                        class="flex items-center gap-2 text-sm"
                      >
                        <div :class="[
                          'h-4 w-4 rounded border flex items-center justify-center text-xs',
                          step.completed ? 'bg-primary border-primary text-primary-foreground' : 'border-muted-foreground/30'
                        ]">
                          <span v-if="step.completed">✓</span>
                        </div>
                        <span :class="step.completed ? 'line-through text-muted-foreground' : ''">
                          {{ step.content }}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Trip Details (Indented under task if task has a trip) -->
              <template v-if="task.trip_id && getTripForTask(task.trip_id)">
                <div class="border-t border-emerald-500/20 ml-6 bg-gradient-to-r from-emerald-500/5 to-transparent">
                  <!-- Trip Header -->
                  <div 
                    class="p-4 flex items-center justify-between cursor-pointer hover:bg-emerald-500/10 transition-all"
                    @click.stop="handleOpenTripDetail(task.trip_id!)"
                  >
                    <div class="flex items-center gap-3">
                      <div class="h-10 w-10 rounded-lg bg-emerald-500/20 flex items-center justify-center">
                        <ShoppingCart class="h-5 w-5 text-emerald-500" />
                      </div>
                      <div>
                        <h4 class="font-medium">
                          {{ getTripForTask(task.trip_id)!.stops.length > 0 ? (getTripForTask(task.trip_id)!.stops[0].store_name || 'Shopping Trip') : 'Shopping Trip' }}
                          <span v-if="getTripForTask(task.trip_id)!.stops.length > 1" class="text-muted-foreground"> +{{ getTripForTask(task.trip_id)!.stops.length - 1 }}</span>
                        </h4>
                        <p class="text-sm text-muted-foreground flex items-center gap-2">
                          <span>{{ getTripForTask(task.trip_id)!.stops.reduce((n: number, s: any) => n + (s.purchases?.length || 0), 0) }} items</span>
                          <span class="text-emerald-500 font-medium">
                            ${{ getTripForTask(task.trip_id)!.stops.reduce((t: number, s: any) => t + (s.purchases || []).reduce((pt: number, p: any) => pt + parseFloat(p.total_price || '0'), 0), 0).toFixed(2) }}
                          </span>
                        </p>
                      </div>
                    </div>
                    <Button variant="ghost" size="sm" @click.stop="handleOpenTripDetail(task.trip_id!)">
                      Manage
                    </Button>
                  </div>
                  
                  <!-- Purchases List (Expanded) -->
                  <div v-if="getTripForTask(task.trip_id)!.stops.some((s: any) => (s.purchases?.length ?? 0) > 0)" class="border-t border-emerald-500/10 px-4 py-3 bg-black/20">
                    <div v-for="stop in getTripForTask(task.trip_id)!.stops" :key="stop.id">
                      <div v-if="(stop.purchases?.length ?? 0) > 0" class="space-y-2">
                        <p v-if="getTripForTask(task.trip_id)!.stops.length > 1" class="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                          {{ stop.store_name }}
                        </p>
                        <div 
                          v-for="purchase in stop.purchases" 
                          :key="purchase.id"
                          class="flex items-center justify-between py-2 border-b border-white/[0.05] last:border-0"
                        >
                          <div class="flex-1 min-w-0">
                            <p class="text-sm font-medium truncate">
                              <span class="text-muted-foreground">{{ purchase.brand }}</span>
                              {{ purchase.item }}
                            </p>
                            <p class="text-xs text-muted-foreground">
                              {{ purchase.count || 1 }}x
                              <span v-if="purchase.units && purchase.unit_measurement">
                                · {{ purchase.units }} {{ purchase.unit_measurement }}
                              </span>
                            </p>
                          </div>
                          <div class="text-right shrink-0 ml-3">
                            <p class="text-sm font-medium text-emerald-500">
                              ${{ parseFloat(purchase.total_price || '0').toFixed(2) }}
                            </p>
                            <p v-if="purchase.taxable" class="text-xs text-muted-foreground">
                              Tax
                            </p>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </template>
            </div>
          </div>
        </div>
      </div>

      <!-- Inline editing overlays (same as week view) -->
      <div 
        v-if="editingTask && !showInlineTripDetail"
        class="absolute inset-0 z-30 bg-card border border-white/[0.12] rounded-lg overflow-hidden"
      >
        <TaskDetailPopout
          :task="editingTask"
          :day-index="0"
          class="h-full"
          @close="closeEditPopout"
          @saved="closeEditPopout"
          @manage-trip="handleOpenTripDetail"
        />
      </div>

      <div 
        v-if="showInlineTripDetail && selectedTripId"
        class="absolute inset-0 z-30 bg-card border border-white/[0.12] rounded-lg overflow-hidden"
      >
        <TripDetailModal
          :trip-id="selectedTripId"
          :inline-mode="true"
          class="h-full"
          @close="closeTripDetailModal"
        />
      </div>
    </div>

    <!-- Desktop Week Calendar Grid -->
    <div v-if="calendarStore.viewMode === 'week' && !showExpandedDayView" class="hidden md:flex flex-1 min-h-0 flex-col rounded-xl border border-white/[0.08] bg-gradient-to-br from-card to-card/95 overflow-hidden shadow-lg shadow-black/5">
      <!-- Day of week headers -->
      <div class="grid grid-cols-7 bg-gradient-to-b from-white/[0.04] to-transparent border-b border-border">
        <div 
          v-for="(day, index) in calendarStore.weekDays" 
          :key="'header-' + day.toISOString()" 
          :class="[
            'py-2.5 text-center border-r border-border last:border-r-0',
            index >= 5 ? 'text-muted-foreground/60' : ''
          ]"
        >
          <p class="text-[11px] font-semibold uppercase tracking-widest text-muted-foreground">
            {{ format(day, 'EEEE') }}
          </p>
          <div class="mt-1 flex items-center justify-center">
            <span 
              :class="[
                'inline-flex items-center justify-center text-lg font-semibold text-foreground/90',
                isToday(day) && 'h-8 w-8 rounded-full ring-2 ring-primary'
              ]"
            >
              {{ format(day, 'd') }}
            </span>
          </div>
        </div>
      </div>

      <!-- Week grid content -->
      <div class="flex-1 grid grid-cols-7 relative">
        <!-- Full-width popout overlay when editing -->
        <div 
          v-if="editingTask && !showInlineTripDetail"
          class="absolute inset-0 z-30 bg-card border border-white/[0.12] rounded-lg overflow-hidden"
        >
          <TaskDetailPopout
            :task="editingTask"
            :day-index="editingDayIndex ?? 0"
            class="h-full"
            @close="closeEditPopout"
            @saved="closeEditPopout"
            @manage-trip="handleOpenTripDetail"
          />
        </div>

        <!-- Inline Trip Detail overlay -->
        <div 
          v-if="showInlineTripDetail && selectedTripId"
          class="absolute inset-0 z-30 bg-card border border-white/[0.12] rounded-lg overflow-hidden"
        >
          <TripDetailModal
            :trip-id="selectedTripId"
            :inline-mode="true"
            class="h-full"
            @close="closeTripDetailModal"
          />
        </div>

        <!-- Day columns -->
        <div
          v-for="(day, dayIndex) in calendarStore.weekDays"
          :key="day.toISOString()"
          :class="[
            'group relative flex flex-col transition-all duration-200 min-w-0',
            'border-r border-border last:border-r-0',
            dayIndex >= 5 
              ? 'bg-white/[0.01]' 
              : 'bg-card',
            'hover:bg-white/[0.03] hover:z-[1]'
          ]"
        >
          <!-- Day Content -->
          <div class="flex-1 px-1.5 py-2 space-y-1 overflow-auto scrollbar-thin relative">
            <!-- Task list (with trip info displayed inline) -->
            <TaskCard
              v-for="task in calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []"
              :key="task.id"
              :task="task"
              :trip="task.trip_id ? getTripByIdFromDate(task.trip_id, format(day, 'yyyy-MM-dd')) : null"
              :day-index="dayIndex"
              @manage-trip="handleOpenTripDetail"
              @edit="(task) => handleEditTask(task, dayIndex)"
            />
          </div>

          <!-- Add task button on hover -->
          <button
            v-if="!editingTask"
            :class="[
              'opacity-0 group-hover:opacity-100 absolute bottom-3 right-3 h-8 w-8 rounded-full flex items-center justify-center transition-all duration-200 z-10',
              'bg-primary/20 hover:bg-primary/30 hover:scale-110',
              'shadow-lg shadow-primary/10'
            ]"
            @click="openNewTask(day)"
          >
            <Plus class="h-4 w-4 text-primary" />
          </button>
        </div>
      </div>
    </div>

    <!-- Desktop Month Calendar Grid -->
    <div v-if="calendarStore.viewMode === 'month' && !showExpandedDayView" class="hidden md:flex flex-1 flex-col rounded-xl border border-white/[0.08] bg-gradient-to-br from-card to-card/95 overflow-hidden shadow-lg shadow-black/5">
      <!-- Day of week headers -->
      <div class="grid grid-cols-7 bg-gradient-to-b from-white/[0.04] to-transparent border-b border-border">
        <div 
          v-for="(dayName, index) in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']" 
          :key="dayName" 
          :class="[
            'py-2.5 text-center text-[11px] font-semibold uppercase tracking-widest',
            index >= 5 ? 'text-muted-foreground/60' : 'text-muted-foreground'
          ]"
        >
          {{ dayName }}
        </div>
      </div>

      <!-- Month grid -->
      <div class="flex-1 grid grid-cols-7 grid-rows-6 gap-px bg-white/[0.03]">
        <div
          v-for="(day, dayIndex) in calendarStore.monthDays"
          :key="day.toISOString()"
          :class="[
            'group relative flex flex-col min-h-[110px] transition-all duration-200',
            'border-r border-b border-border',
            isToday(day) 
              ? 'bg-primary/[0.06] ring-1 ring-inset ring-primary/20' 
              : !isSameMonth(day, calendarStore.currentDate)
                ? 'bg-black/20'
                : dayIndex % 7 >= 5 
                  ? 'bg-white/[0.01]' 
                  : 'bg-card',
            'hover:bg-white/[0.03] hover:z-[1]'
          ]"
        >
          <!-- Day Header -->
          <div 
            :class="[
              'px-2 py-1.5 flex items-center justify-between border-b',
              isToday(day) 
                ? 'border-primary/10 bg-primary/[0.03]' 
                : 'border-transparent'
            ]"
          >
            <!-- Day number -->
            <span 
              :class="[
                'inline-flex items-center justify-center font-semibold transition-all',
                isToday(day) 
                  ? 'h-7 w-7 rounded-full bg-primary text-primary-foreground text-sm shadow-lg shadow-primary/30' 
                  : !isSameMonth(day, calendarStore.currentDate)
                    ? 'text-muted-foreground/30 text-sm'
                    : 'text-foreground/90 text-sm'
              ]"
            >
              {{ format(day, 'd') }}
            </span>
            
            <!-- Task count badge -->
            <span 
              v-if="getTaskCount(day) > 0" 
              :class="[
                'inline-flex items-center gap-1 text-[10px] font-medium px-1.5 py-0.5 rounded-full transition-colors',
                isToday(day)
                  ? 'bg-primary/20 text-primary'
                  : 'bg-white/[0.06] text-muted-foreground/70'
              ]"
            >
              {{ getTaskCount(day) }}
            </span>
          </div>

          <!-- Day Content -->
          <div class="flex-1 px-1.5 py-1 space-y-0.5 overflow-hidden relative">
            <!-- Task list with compact cards (trip info displayed inline) -->
            <TaskCard
              v-for="task in (calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []).slice(0, 4)"
              :key="task.id"
              :task="task"
              :trip="task.trip_id ? getTripByIdFromDate(task.trip_id, format(day, 'yyyy-MM-dd')) : null"
              :compact="true"
              @manage-trip="handleOpenTripDetail"
            />
            
            <!-- Overflow indicator -->
            <button 
              v-if="(calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []).length > 4"
              :class="[
                'flex items-center justify-center gap-1 w-full py-1 rounded-md text-[10px] font-medium transition-all cursor-pointer',
                'bg-gradient-to-r from-white/[0.03] to-transparent',
                'hover:from-white/[0.08] hover:to-white/[0.02]',
                'text-muted-foreground/70 hover:text-primary'
              ]"
              @click.stop="toggleExpandedDay(day)"
            >
              <span class="inline-flex items-center justify-center h-4 min-w-[16px] px-1 rounded-sm bg-white/[0.08] text-[9px]">
                +{{ (calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []).length - 4 }}
              </span>
              <span>more</span>
            </button>
            
            <!-- Empty state indicator -->
            <div 
              v-if="(calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []).length === 0 && isSameMonth(day, calendarStore.currentDate)"
              class="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
            >
              <div class="w-8 h-8 rounded-full bg-white/[0.03] flex items-center justify-center border border-dashed border-white/[0.08]">
                <Plus class="h-4 w-4 text-muted-foreground/40" />
              </div>
            </div>
            
            <!-- Expanded Tasks Dropdown -->
            <div 
              v-if="expandedDay === format(day, 'yyyy-MM-dd')" 
              class="absolute left-[-1px] right-[-1px] top-[-1px] z-20 backdrop-blur-xl bg-card/95 border border-white/[0.1] shadow-2xl shadow-black/40 rounded-lg flex flex-col p-2.5 min-h-[calc(100%+2px)] max-h-[350px]"
            >
              <!-- Expanded header -->
              <div class="flex items-center justify-between mb-2 pb-2 border-b border-white/[0.08]">
                <div class="flex items-center gap-2">
                  <span class="text-sm font-semibold">{{ format(day, 'MMM d') }}</span>
                  <span class="text-[10px] text-muted-foreground px-1.5 py-0.5 rounded-full bg-white/[0.06]">
                    {{ (calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []).length }} tasks
                  </span>
                </div>
                <button 
                  class="h-6 w-6 rounded-full hover:bg-white/[0.1] flex items-center justify-center text-muted-foreground transition-colors"
                  @click.stop="expandedDay = null"
                >
                  <X class="h-3.5 w-3.5" />
                </button>
              </div>
              
              <!-- Expanded task list -->
              <div class="flex-1 overflow-y-auto space-y-1.5 scrollbar-thin pr-1">
                <TaskCard
                  v-for="task in (calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || [])"
                  :key="task.id"
                  :task="task"
                  :trip="task.trip_id ? getTripByIdFromDate(task.trip_id, format(day, 'yyyy-MM-dd')) : null"
                  @manage-trip="handleOpenTripDetail"
                />
              </div>
              
              <!-- Add task in expanded view -->
              <button 
                class="mt-2 pt-2 border-t border-white/[0.06] flex items-center justify-center gap-1.5 py-1.5 text-[11px] text-muted-foreground/70 hover:text-primary transition-colors"
                @click="openNewTask(day)"
              >
                <Plus class="h-3.5 w-3.5" />
                Add task
              </button>
            </div>

            <!-- Backdrop for closing -->
            <div 
              v-if="expandedDay === format(day, 'yyyy-MM-dd')" 
              class="fixed inset-0 z-10 bg-black/20 backdrop-blur-sm cursor-default" 
              @click.stop="expandedDay = null" 
            />
          </div>

          <!-- Add task button on hover -->
          <button
            :class="[
              'opacity-0 group-hover:opacity-100 absolute bottom-2 right-2 h-7 w-7 rounded-full flex items-center justify-center transition-all duration-200 z-10',
              'bg-primary/20 hover:bg-primary/30 hover:scale-110',
              'shadow-lg shadow-primary/10'
            ]"
            @click="openNewTask(day)"
          >
            <Plus class="h-4 w-4 text-primary" />
          </button>
        </div>
      </div>
    </div>

    <TaskForm
      v-if="showTaskForm"
      :task="selectedTask || undefined"
      :initial-date="selectedDate"
      @close="closeTaskForm"
      @saved="closeTaskForm"
      :manage-trip-action="handleOpenTripDetail"
      @manage-trip="handleOpenTripDetail"
    />

    <!-- Keep TripDetailModal for month view/mobile/when TaskForm modal is open -->
    <TripDetailModal
      v-if="showInlineTripDetail && selectedTripId && (calendarStore.viewMode !== 'week' || isMobile || showTaskForm)"
      :trip-id="selectedTripId"
      @close="closeTripDetailModal"
    />
  </div>
</template>
