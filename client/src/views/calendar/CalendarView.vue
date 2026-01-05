<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { format, isToday, isSameDay, isSameMonth } from 'date-fns'
import { ChevronLeft, ChevronRight, Plus, Calendar, CalendarDays } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { useCalendarStore } from '@/stores/calendar'
import TaskCard from '@/components/calendar/TaskCard.vue'
import TaskForm from '@/components/calendar/TaskForm.vue'
import { cn } from '@/lib/utils'

const calendarStore = useCalendarStore()
const showTaskForm = ref(false)
const selectedDate = ref<Date | null>(null)
const mobileSelectedDay = ref<Date>(new Date())

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
  selectedDate.value = date || mobileSelectedDay.value || new Date()
  showTaskForm.value = true
}

const closeTaskForm = () => {
  showTaskForm.value = false
  selectedDate.value = null
}
</script>

<template>
  <div class="h-full flex flex-col animate-fade-in">
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
        <!-- View Toggle -->
        <div class="flex items-center rounded-lg border border-border bg-card overflow-hidden">
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
        </div>

        <!-- Navigation -->
        <div class="flex items-center rounded-lg border border-border bg-card overflow-hidden">
          <Button variant="ghost" size="icon" class="rounded-none h-9 w-9" @click="calendarStore.prevPeriod">
            <ChevronLeft class="h-4 w-4" />
          </Button>
          <div class="w-px h-5 bg-border" />
          <Button variant="ghost" size="sm" class="rounded-none px-3 sm:px-4 h-9 text-[13px]" @click="calendarStore.goToToday">
            Today
          </Button>
          <div class="w-px h-5 bg-border" />
          <Button variant="ghost" size="icon" class="rounded-none h-9 w-9" @click="calendarStore.nextPeriod">
            <ChevronRight class="h-4 w-4" />
          </Button>
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
    <div v-if="calendarStore.viewMode === 'week'" class="hidden md:grid flex-1 grid-cols-7 gap-px bg-border/80 rounded-xl overflow-hidden border border-border/80">
      <div
        v-for="day in calendarStore.weekDays"
        :key="day.toISOString()"
        :class="[
          'bg-card flex flex-col',
          isToday(day) && 'bg-primary/[0.02]'
        ]"
      >
        <!-- Day Header -->
        <div 
          :class="[
            'p-3 border-b border-border/60 text-center',
            isToday(day) && 'bg-primary/5'
          ]"
        >
          <p class="text-[11px] font-medium text-muted-foreground uppercase tracking-wider">
            {{ format(day, 'EEE') }}
          </p>
          <div class="mt-1 flex items-center justify-center">
            <span 
              :class="[
                'inline-flex items-center justify-center text-lg font-semibold',
                isToday(day) 
                  ? 'h-8 w-8 rounded-full bg-primary text-primary-foreground' 
                  : 'text-foreground'
              ]"
            >
              {{ format(day, 'd') }}
            </span>
          </div>
        </div>

        <!-- Day Content -->
        <div class="flex-1 p-1.5 space-y-1 overflow-auto scrollbar-thin min-h-[200px]">
          <TaskCard
            v-for="task in calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []"
            :key="task.id"
            :task="task"
          />

          <button
            class="w-full p-2 border border-dashed border-border/60 rounded-lg text-muted-foreground/60 hover:border-primary/40 hover:text-primary hover:bg-primary/5 transition-all"
            @click="openNewTask(day)"
          >
            <Plus class="h-4 w-4 mx-auto" />
          </button>
        </div>
      </div>
    </div>

    <!-- Desktop Month Calendar Grid -->
    <div v-if="calendarStore.viewMode === 'month'" class="hidden md:flex flex-1 flex-col rounded-xl overflow-hidden border border-border/80">
      <!-- Day of week headers -->
      <div class="grid grid-cols-7 bg-secondary/50 border-b border-border/60">
        <div 
          v-for="dayName in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']" 
          :key="dayName" 
          class="py-2 text-center text-xs font-medium text-muted-foreground uppercase tracking-wider"
        >
          {{ dayName }}
        </div>
      </div>

      <!-- Month grid -->
      <div class="flex-1 grid grid-cols-7 grid-rows-6 gap-px bg-border/60">
        <div
          v-for="day in calendarStore.monthDays"
          :key="day.toISOString()"
          :class="[
            'group relative bg-card flex flex-col min-h-[100px] overflow-hidden transition-colors',
            isToday(day) && 'bg-primary/[0.03]',
            !isSameMonth(day, calendarStore.currentDate) && 'bg-secondary/30'
          ]"
        >
          <!-- Day Header -->
          <div 
            :class="[
              'px-2 py-1 flex items-center justify-between',
              isToday(day) && 'bg-primary/5'
            ]"
          >
            <span 
              :class="[
                'inline-flex items-center justify-center text-sm font-medium',
                isToday(day) 
                  ? 'h-6 w-6 rounded-full bg-primary text-primary-foreground text-xs' 
                  : !isSameMonth(day, calendarStore.currentDate)
                    ? 'text-muted-foreground/50'
                    : 'text-foreground'
              ]"
            >
              {{ format(day, 'd') }}
            </span>
            <span v-if="getTaskCount(day) > 0" class="text-[10px] text-muted-foreground">
              {{ getTaskCount(day) }} {{ getTaskCount(day) === 1 ? 'task' : 'tasks' }}
            </span>
          </div>

          <!-- Day Content -->
          <div class="flex-1 px-1 pb-1 space-y-0.5 overflow-auto scrollbar-thin">
            <div
              v-for="task in (calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []).slice(0, 3)"
              :key="task.id"
              :class="[
                'px-1.5 py-0.5 text-[11px] rounded truncate cursor-pointer transition-colors',
                task.status === 'completed'
                  ? 'bg-secondary/60 text-muted-foreground line-through'
                  : 'bg-primary/10 text-primary hover:bg-primary/20'
              ]"
              @click="() => { selectedDate = day; showTaskForm = true }"
            >
              {{ task.title }}
            </div>
            <div 
              v-if="(calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []).length > 3"
              class="text-[10px] text-muted-foreground px-1.5"
            >
              +{{ (calendarStore.tasksByDate[format(day, 'yyyy-MM-dd')] || []).length - 3 }} more
            </div>
          </div>

          <!-- Add task button on hover -->
          <button
            class="opacity-0 group-hover:opacity-100 absolute bottom-1 right-1 h-6 w-6 rounded-full bg-primary/10 flex items-center justify-center transition-opacity hover:bg-primary/20"
            @click="openNewTask(day)"
          >
            <Plus class="h-3.5 w-3.5 text-primary" />
          </button>
        </div>
      </div>
    </div>

    <TaskForm
      v-if="showTaskForm"
      :initial-date="selectedDate"
      @close="closeTaskForm"
      @saved="closeTaskForm"
    />
  </div>
</template>
