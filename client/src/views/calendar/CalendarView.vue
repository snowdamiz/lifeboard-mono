<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { format, isToday, isSameDay, isSameMonth } from 'date-fns'
import { ChevronLeft, ChevronRight, Plus, Calendar, CalendarDays, X } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { useCalendarStore } from '@/stores/calendar'
import TaskCard from '@/components/calendar/TaskCard.vue'
import TripCard from '@/components/calendar/TripCard.vue'
import TaskForm from '@/components/calendar/TaskForm.vue'
import TaskDetailPopout from '@/components/calendar/TaskDetailPopout.vue'
import { cn } from '@/lib/utils'
import type { Task } from '@/types'

const calendarStore = useCalendarStore()
const showTaskForm = ref(false)
const selectedDate = ref<Date | null>(null)
const selectedTask = ref<Task | null>(null)
const mobileSelectedDay = ref<Date>(new Date())
const expandedDay = ref<string | null>(null) // Stores ISO string of expanded day in month view

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
  if (calendarStore.viewMode === 'month') {
    return format(calendarStore.currentDate, 'MMMM yyyy')
  }
  return `${format(calendarStore.weekStart, 'MMMM d')} – ${format(calendarStore.weekEnd, 'MMMM d, yyyy')}`
})

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

const openEditTask = (task: Task, date: Date) => {
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
        <Button variant="outline" size="sm" class="h-9 px-3 text-[13px]" @click="calendarStore.goToToday">
          Today
        </Button>

        <!-- Navigation with View Toggle -->
        <div class="flex items-center rounded-lg border border-border bg-card overflow-hidden">
          <Button variant="ghost" size="icon" class="rounded-none h-9 w-9" @click="calendarStore.prevPeriod" title="Previous">
            <ChevronLeft class="h-4 w-4" />
          </Button>
          <div class="w-px h-5 bg-border" />
          <Button 
            :variant="calendarStore.viewMode === 'week' ? 'default' : 'ghost'" 
            size="sm" 
            class="rounded-none h-9 px-3 gap-1.5"
            @click="calendarStore.viewMode !== 'week' && toggleViewMode()"
          >
            <Calendar class="h-4 w-4" />
            <span class="hidden sm:inline text-[13px]">Week</span>
          </Button>
          <div class="w-px h-5 bg-border" />
          <Button 
            :variant="calendarStore.viewMode === 'month' ? 'default' : 'ghost'" 
            size="sm" 
            class="rounded-none h-9 px-3 gap-1.5"
            @click="calendarStore.viewMode !== 'month' && toggleViewMode()"
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
        
        <Button @click="openNewTask()" class="shrink-0">
          <Plus class="h-4 w-4" />
          <span class="hidden sm:inline">New Task</span>
        </Button>
      </div>
    </div>

    <!-- Mobile Day Picker - Week View -->
    <div v-if="calendarStore.viewMode === 'week'" class="md:hidden mb-4">
      <div class="flex gap-1 overflow-x-auto pb-2 scrollbar-thin -mx-2 px-2">
        <button
          v-for="day in calendarStore.weekDays"
          :key="day.toISOString()"
          :class="cn(
            'relative flex-shrink-0 flex flex-col items-center justify-center w-14 h-16 rounded-xl transition-all',
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
          class="!p-3"
          @manage-trip="handleOpenTripDetail"
        />

        <div 
          v-if="mobileSelectedDayTasks.length === 0" 
          class="flex flex-col items-center justify-center py-12 text-center"
        >
          <div class="h-12 w-12 rounded-full bg-secondary flex items-center justify-center mb-3">
            <Plus class="h-6 w-6 text-muted-foreground" />
          </div>
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

    <!-- Desktop Week Calendar Grid -->
    <div v-if="calendarStore.viewMode === 'week'" class="hidden md:flex flex-1 min-h-0 flex-col rounded-xl border border-white/[0.08] bg-gradient-to-br from-card to-card/95 overflow-hidden shadow-lg shadow-black/5">
      <!-- Day of week headers -->
      <div class="grid grid-cols-7 bg-gradient-to-b from-white/[0.04] to-transparent border-b border-white/[0.06]">
        <div 
          v-for="(day, index) in calendarStore.weekDays" 
          :key="'header-' + day.toISOString()" 
          :class="[
            'py-2.5 text-center border-r border-white/[0.04] last:border-r-0',
            index >= 5 ? 'text-muted-foreground/60' : ''
          ]"
        >
          <p class="text-[11px] font-semibold uppercase tracking-widest text-muted-foreground">
            {{ format(day, 'EEEE') }}
          </p>
          <div class="mt-1 flex items-center justify-center">
            <span 
              :class="[
                'inline-flex items-center justify-center text-lg font-semibold transition-all',
                isToday(day) 
                  ? 'h-8 w-8 rounded-full bg-primary text-primary-foreground shadow-lg shadow-primary/30' 
                  : 'text-foreground/90'
              ]"
            >
              {{ format(day, 'd') }}
            </span>
          </div>
        </div>
      </div>

      <!-- Week grid content -->
      <div class="flex-1 flex gap-px bg-white/[0.03] relative">
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
            'group relative flex flex-col flex-1 w-full transition-all duration-200',
            'border-r border-white/[0.04] last:border-r-0',
            isToday(day) 
              ? 'bg-primary/[0.06] ring-1 ring-inset ring-primary/20' 
              : dayIndex >= 5 
                ? 'bg-white/[0.01]' 
                : 'bg-card',
            'hover:bg-white/[0.03] hover:z-[1]'
          ]"
        >
          <!-- Day Content -->
          <div class="flex-1 px-1.5 py-2 space-y-1 overflow-auto scrollbar-thin relative">
            <!-- Trips list -->
            <TripCard
              v-for="trip in calendarStore.tripsByDate[format(day, 'yyyy-MM-dd')] || []"
              :key="trip.id"
              :trip="trip"
              @click="handleOpenTripDetail"
            />
            <!-- Task list -->
            <TaskCard
              v-for="task in calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []"
              :key="task.id"
              :task="task"
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
    <div v-if="calendarStore.viewMode === 'month'" class="hidden md:flex flex-1 flex-col rounded-xl border border-white/[0.08] bg-gradient-to-br from-card to-card/95 overflow-hidden shadow-lg shadow-black/5">
      <!-- Day of week headers -->
      <div class="grid grid-cols-7 bg-gradient-to-b from-white/[0.04] to-transparent border-b border-white/[0.06]">
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
            'border-r border-b border-white/[0.04]',
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
            <!-- Trips list with compact cards -->
            <TripCard
              v-for="trip in (calendarStore.tripsByDate[format(day, 'yyyy-MM-dd')] || []).slice(0, 2)"
              :key="trip.id"
              :trip="trip"
              :compact="true"
              @click="handleOpenTripDetail"
            />
            <!-- Task list with compact cards -->
            <TaskCard
              v-for="task in (calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []).slice(0, 4)"
              :key="task.id"
              :task="task"
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

    <!-- Keep TripDetailModal for month view/mobile -->
    <TripDetailModal
      v-if="showInlineTripDetail && selectedTripId && calendarStore.viewMode !== 'week'"
      :trip-id="selectedTripId"
      @close="closeTripDetailModal"
    />
  </div>
</template>
