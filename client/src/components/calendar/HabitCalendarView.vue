<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { 
  format, isToday, isSameDay, isSameMonth, startOfMonth, endOfMonth, 
  startOfWeek, endOfWeek, eachDayOfInterval, addMonths, subMonths, 
  addWeeks, subWeeks, addDays, subDays, parseISO, startOfDay
} from 'date-fns'
import { ChevronLeft, ChevronRight, CheckCircle2, Circle, Ban, Calendar as CalendarIcon, Edit2, CheckSquare, Square, Pin } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { useHabitsStore } from '@/stores/habits'
import type { HabitWithStatus } from '@/stores/habits'

const emit = defineEmits<{
  (e: 'edit', habit: HabitWithStatus): void
}>()

const habitsStore = useHabitsStore()
const viewMode = ref<'day' | 'week' | 'month'>('week')
const currentDate = ref(new Date())

// Selection mode state
const selectionMode = ref(false)
const selectedHabitIds = ref<Set<string>>(new Set())

// Pin today to top state
const pinTodayToTop = ref(false)

// Toggle selection mode
const toggleSelectionMode = () => {
  selectionMode.value = !selectionMode.value
  if (!selectionMode.value) {
    selectedHabitIds.value = new Set()
  }
}

// Toggle habit selection
const toggleHabitSelection = (habitId: string) => {
  const newSet = new Set(selectedHabitIds.value)
  if (newSet.has(habitId)) {
    newSet.delete(habitId)
  } else {
    newSet.add(habitId)
  }
  selectedHabitIds.value = newSet
}

// Select/Deselect all today's habits
const selectAllToday = () => {
  const todayHabits = habitsForDay(new Date())
  const pendingHabits = todayHabits.filter(h => !h.completed_today)
  selectedHabitIds.value = new Set(pendingHabits.map(h => h.id))
}

const deselectAll = () => {
  selectedHabitIds.value = new Set()
}

// Bulk complete selected habits
const bulkCompleteSelected = async () => {
  const idsToComplete = Array.from(selectedHabitIds.value)
  for (const id of idsToComplete) {
    const habit = habitsStore.habits.find(h => h.id === id)
    if (habit && !habit.completed_today) {
      await habitsStore.completeHabit(id)
    }
  }
  selectedHabitIds.value = new Set()
  selectionMode.value = false
}

// Toggle habit completion (for today only)
const handleToggleComplete = async (habit: HabitWithStatus) => {
  if (habit.completed_today) {
    await habitsStore.uncompleteHabit(habit.id)
  } else {
    await habitsStore.completeHabit(habit.id)
  }
}

// Helper to parse time string (HH:MM) to minutes since midnight
const timeToMinutes = (timeStr: string | null): number => {
  if (!timeStr) return 9999 // Put unscheduled habits at the end
  const [hours, minutes] = timeStr.split(':').map(Number)
  return hours * 60 + minutes
}

// Sort habits by scheduled time
const sortHabitsByTime = (habits: HabitWithStatus[]): HabitWithStatus[] => {
  return [...habits].sort((a, b) => {
    const timeA = timeToMinutes(a.scheduled_time)
    const timeB = timeToMinutes(b.scheduled_time)
    return timeA - timeB
  })
}

// Format time as readable (e.g., "9:00am")
const formatTimeReadable = (timeStr: string | null): string => {
  if (!timeStr) return 'Anytime'
  const [hours, minutes] = timeStr.split(':').map(Number)
  const period = hours >= 12 ? 'pm' : 'am'
  const displayHours = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours
  return `${displayHours}:${minutes.toString().padStart(2, '0')}${period}`
}

// Format duration in minutes as "Xh Ym" when >= 60, or "Xm" when < 60
const formatDuration = (minutes: number | null): string => {
  if (!minutes || minutes <= 0) return ''
  if (minutes < 60) return `${minutes}m`
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  if (mins === 0) return `${hours}h`
  return `${hours}h ${mins}m`
}

// Calculate calendar ranges
const monthStart = computed(() => startOfMonth(currentDate.value))
const monthEnd = computed(() => endOfMonth(currentDate.value))
const weekStart = computed(() => startOfWeek(currentDate.value, { weekStartsOn: 0 }))
const weekEnd = computed(() => endOfWeek(currentDate.value, { weekStartsOn: 0 }))

// Get calendar days
const calendarDays = computed(() => {
  if (viewMode.value === 'month') {
    const start = startOfWeek(monthStart.value, { weekStartsOn: 0 })
    const end = endOfWeek(monthEnd.value, { weekStartsOn: 0 })
    return eachDayOfInterval({ start, end })
  } else {
    return eachDayOfInterval({ start: weekStart.value, end: weekEnd.value })
  }
})

const weekDays = computed(() => {
  const days = eachDayOfInterval({ start: weekStart.value, end: weekEnd.value })
  
  // If pin today is enabled and today is in the current week, move it to the top
  if (pinTodayToTop.value) {
    const today = new Date()
    const todayIndex = days.findIndex(d => isToday(d))
    if (todayIndex > 0) {
      // Move today to the front
      const todayDay = days[todayIndex]
      const reordered = [todayDay, ...days.slice(0, todayIndex), ...days.slice(todayIndex + 1)]
      return reordered
    }
  }
  
  return days
})

// Navigation
const goToPrevious = () => {
  if (viewMode.value === 'month') {
    currentDate.value = subMonths(currentDate.value, 1)
  } else if (viewMode.value === 'week') {
    currentDate.value = subWeeks(currentDate.value, 1)
  } else {
    currentDate.value = subDays(currentDate.value, 1)
  }
}

const goToNext = () => {
  if (viewMode.value === 'month') {
    currentDate.value = addMonths(currentDate.value, 1)
  } else if (viewMode.value === 'week') {
    currentDate.value = addWeeks(currentDate.value, 1)
  } else {
    currentDate.value = addDays(currentDate.value, 1)
  }
}

const goToToday = () => {
  currentDate.value = new Date()
}

const toggleViewMode = () => {
  const modes: ('day' | 'week' | 'month')[] = ['day', 'week', 'month']
  const currentIndex = modes.indexOf(viewMode.value)
  viewMode.value = modes[(currentIndex + 1) % modes.length]
}

// Header text
const headerText = computed(() => {
  if (viewMode.value === 'month') {
    return format(currentDate.value, 'MMMM yyyy')
  } else if (viewMode.value === 'week') {
    return `${format(weekStart.value, 'MMM d')} – ${format(weekEnd.value, 'MMM d, yyyy')}`
  } else {
    return format(currentDate.value, 'EEEE, MMMM d, yyyy')
  }
})

// Get habits for a specific day (filter by day of week for recurring)
const habitsForDay = (day: Date): HabitWithStatus[] => {
  // For now, show all daily habits and weekly habits that match the day of week
  const dayOfWeek = day.getDay() // 0 = Sunday, 1 = Monday, etc.
  const dayStart = startOfDay(day)
  
  const filtered = habitsStore.habits.filter(habit => {
    // Don't show habit on days before it was created
    const habitCreatedAt = startOfDay(parseISO(habit.inserted_at))
    if (dayStart < habitCreatedAt) return false
    
    if (habit.frequency === 'daily') return true
    if (habit.frequency === 'weekly' && habit.days_of_week?.includes(dayOfWeek)) return true
    return false
  })
  
  return sortHabitsByTime(filtered)
}

const dayColor = (day: Date, habit: HabitWithStatus) => {
  // This would check completion status from the backend
  // For now, just return the habit color with opacity based on today
  if (isToday(day) && habit.completed_today) {
    return habit.color
  }
  return habit.color + '40' // 25% opacity
}

// Computed for selection count
const selectedCount = computed(() => selectedHabitIds.value.size)

onMounted(() => {
  habitsStore.fetchHabits()
})
</script>

<template>
  <div class="space-y-4">
    <!-- Header with navigation -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <CalendarIcon class="h-5 w-5 text-primary" />
        </div>
        <h2 class="text-xl font-semibold">{{ headerText }}</h2>
      </div>

      <div class="flex items-center gap-2">
        <Button variant="outline" size="sm" @click="goToToday">
          Today
        </Button>
        <Button variant="outline" size="icon" @click="goToPrevious">
          <ChevronLeft class="h-4 w-4" />
        </Button>
        <Button variant="outline" size="icon" @click="goToNext">
          <ChevronRight class="h-4 w-4" />
        </Button>
        <Button variant="outline" size="sm" @click="toggleViewMode">
          {{ viewMode === 'day' ? 'Week' : viewMode === 'week' ? 'Month' : 'Day' }}
        </Button>
      </div>
      
      <!-- Legend inline -->
      <div class="flex items-center gap-3 text-xs border-l border-border pl-3 ml-2">
        <div class="flex items-center gap-1">
          <CheckCircle2 class="h-3 w-3 text-primary" />
          <span class="text-muted-foreground">Completed</span>
        </div>
        <div class="flex items-center gap-1">
          <Circle class="h-3 w-3 text-muted-foreground" />
          <span class="text-muted-foreground">Pending</span>
        </div>
        <div class="flex items-center gap-1">
          <Ban class="h-3 w-3 text-muted-foreground" />
          <span class="text-muted-foreground">Skipped</span>
        </div>
      </div>
    </div>

    <!-- Selection Mode Toolbar -->
    <div class="flex items-center gap-2 flex-wrap">
      <Button 
        :variant="selectionMode ? 'default' : 'outline'" 
        size="sm" 
        @click="toggleSelectionMode"
        class="gap-1.5"
      >
        <CheckSquare v-if="selectionMode" class="h-4 w-4" />
        <Square v-else class="h-4 w-4" />
        {{ selectionMode ? 'Exit Selection' : 'Select Mode' }}
      </Button>
      
      <!-- Pin today toggle (only in week view) -->
      <Button 
        v-if="viewMode === 'week'"
        :variant="pinTodayToTop ? 'default' : 'outline'" 
        size="sm" 
        @click="pinTodayToTop = !pinTodayToTop"
        class="gap-1.5"
      >
        <Pin class="h-4 w-4" />
        {{ pinTodayToTop ? 'Unpin Today' : 'Pin Today' }}
      </Button>
      
      <template v-if="selectionMode">
        <Button variant="outline" size="sm" @click="selectAllToday">
          Select All Pending
        </Button>
        <Button variant="outline" size="sm" @click="deselectAll" :disabled="selectedCount === 0">
          Deselect All
        </Button>
        <Button 
          variant="default" 
          size="sm" 
          @click="bulkCompleteSelected"
          :disabled="selectedCount === 0"
          class="gap-1.5"
        >
          <CheckCircle2 class="h-4 w-4" />
          Complete Selected ({{ selectedCount }})
        </Button>
      </template>
    </div>

    <!-- Calendar Grid -->
    <Card v-if="viewMode === 'month'">
      <CardContent class="p-4">
        <!-- Day headers -->
        <div class="grid grid-cols-7 gap-2 mb-2">
          <div 
            v-for="day in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']" 
            :key="day"
            class="text-center text-xs font-medium text-muted-foreground py-2"
          >
            {{ day }}
          </div>
        </div>

        <!-- Calendar days -->
        <div class="grid grid-cols-7 gap-2">
          <div
            v-for="day in calendarDays"
            :key="day.toISOString()"
            :class="[
              'min-h-24 p-2 rounded-lg border transition-colors',
              isToday(day) ? 'bg-primary/5 border-primary/50' : 'border-border hover:bg-accent',
              !isSameMonth(day, monthStart) && 'opacity-40'
            ]"
          >
            <div class="text-sm font-medium mb-1" :class="isToday(day) && 'text-primary'">
              {{ format(day, 'd') }}
            </div>

            <!-- Habits for this day -->
            <div class="space-y-1">
              <div
                v-for="habit in habitsForDay(day).slice(0, 3)"
                :key="habit.id"
                class="flex items-center gap-1 text-xs"
              >
                <div 
                  class="h-2 w-2 rounded-full flex-shrink-0" 
                  :style="{ backgroundColor: dayColor(day, habit) }"
                />
                <span class="truncate text-muted-foreground">{{ habit.name }}</span>
              </div>
              <div 
                v-if="habitsForDay(day).length > 3" 
                class="text-xs text-muted-foreground"
              >
                +{{ habitsForDay(day).length - 3 }} more
              </div>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>

    <!-- Week View -->
    <div v-else class="space-y-3">
      <div 
        v-for="day in weekDays" 
        :key="day.toISOString()"
        :class="[
          'rounded-lg border p-4 transition-colors',
          isToday(day) ? 'bg-primary/5 border-primary/50' : 'border-border'
        ]"
      >
        <div class="flex items-center justify-between mb-3">
          <div>
            <h3 class="font-semibold" :class="isToday(day) && 'text-primary'">
              {{ format(day, 'EEEE') }}
            </h3>
            <p class="text-sm text-muted-foreground">{{ format(day, 'MMMM d, yyyy') }}</p>
          </div>
          <Badge v-if="isToday(day)" variant="default">Today</Badge>
        </div>

        <div class="space-y-2">
          <div
            v-for="habit in habitsForDay(day)"
            :key="habit.id"
            class="flex items-center gap-2 p-2 rounded-lg bg-card border border-border/50 group hover:shadow-md transition-all cursor-pointer"
            :style="{ borderLeft: `3px solid ${habit.color || '#10b981'}` }"
          >
            <!-- Selection checkbox (only for today) -->
            <button
              v-if="selectionMode && isToday(day)"
              @click="toggleHabitSelection(habit.id)"
              class="flex-shrink-0 focus:outline-none"
            >
              <div 
                class="h-4 w-4 rounded flex items-center justify-center transition-all"
                :class="selectedHabitIds.has(habit.id) ? 'bg-primary' : 'border-2 border-dashed border-muted-foreground/30'"
              >
                <CheckCircle2 v-if="selectedHabitIds.has(habit.id)" class="h-2.5 w-2.5 text-primary-foreground" />
              </div>
            </button>

            <!-- Clickable status icon (only for today) -->
            <button
              v-if="isToday(day) && !selectionMode"
              @click="handleToggleComplete(habit)"
              class="flex-shrink-0 focus:outline-none"
            >
              <div 
                v-if="habit.completed_today"
                class="h-4 w-4 rounded flex items-center justify-center"
                :style="{ backgroundColor: habit.color + '20' }"
              >
                <CheckCircle2 class="h-2.5 w-2.5" :style="{ color: habit.color }" />
              </div>
              <div v-else class="h-4 w-4 rounded border-2 border-dashed border-muted-foreground/30 flex items-center justify-center hover:border-muted-foreground/50">
                <Circle class="h-2.5 w-2.5 text-muted-foreground/30" />
              </div>
            </button>

            <!-- Static status icon (for non-today days) -->
            <div 
              v-if="!isToday(day)"
              class="h-4 w-4 rounded flex items-center justify-center flex-shrink-0"
              :style="{ backgroundColor: habit.color + '20' }"
            >
              <Circle class="h-2.5 w-2.5 text-muted-foreground" />
            </div>

            <div class="flex-1 min-w-0">
              <h4 :class="['text-xs font-medium truncate', habit.completed_today && isToday(day) && 'line-through text-muted-foreground']">{{ habit.name }}</h4>
              <div class="flex items-center gap-1">
                <span class="text-[9px] text-foreground/80">{{ formatTimeReadable(habit.scheduled_time) }}</span>
                <span v-if="habit.duration_minutes" class="text-[9px] text-foreground/80">· {{ formatDuration(habit.duration_minutes) }}</span>
              </div>
            </div>

            <!-- Edit button (only for today, shows on hover) -->
            <Button 
              v-if="isToday(day) && !selectionMode"
              variant="ghost" 
              size="icon" 
              class="h-6 w-6 opacity-0 group-hover:opacity-100 transition-opacity"
              @click="emit('edit', habit)"
            >
              <Edit2 class="h-3 w-3" />
            </Button>
          </div>

          <div 
            v-if="habitsForDay(day).length === 0"
            class="text-center py-4 text-muted-foreground text-sm"
          >
            No habits scheduled
          </div>
        </div>
      </div>
    </div>

    <!-- Day View - Detailed Timeline -->
    <div v-if="viewMode === 'day'" class="space-y-3">
      <Card>
        <CardContent class="p-6">
          <div class="mb-4">
            <Badge v-if="isToday(currentDate)" variant="default" class="mb-2">Today</Badge>
            <h3 class="font-semibold text-lg">{{ format(currentDate, 'EEEE, MMMM d, yyyy') }}</h3>
            <p class="text-sm text-muted-foreground mt-1">
              {{ habitsForDay(currentDate).length }} habit{{ habitsForDay(currentDate).length !== 1 ? 's' : '' }} scheduled
            </p>
          </div>

          <!-- Timeline of habits sorted by time -->
          <div class="space-y-2">
            <div
              v-for="habit in habitsForDay(currentDate)"
              :key="habit.id"
              class="flex items-start gap-4 p-4 rounded-lg border transition-colors hover:bg-accent group"
              :class="isToday(currentDate) && habit.completed_today && 'bg-accent/50 border-primary/30'"
            >
              <!-- Time column -->
              <div class="w-20 flex-shrink-0 text-right">
                <div class="text-sm font-medium" :class="habit.scheduled_time ? 'text-foreground' : 'text-muted-foreground'">
                  {{ habit.scheduled_time || 'Anytime' }}
                </div>
                <div v-if="habit.duration_minutes" class="text-xs text-muted-foreground mt-0.5">
                  {{ habit.duration_minutes }}min
                </div>
              </div>

              <!-- Selection checkbox (only for today in day view) -->
              <button
                v-if="selectionMode && isToday(currentDate)"
                @click="toggleHabitSelection(habit.id)"
                class="flex-shrink-0 pt-1 focus:outline-none"
              >
                <div 
                  class="h-8 w-8 rounded border-2 flex items-center justify-center transition-all"
                  :class="selectedHabitIds.has(habit.id) ? 'bg-primary border-primary' : 'border-muted-foreground/30 hover:border-muted-foreground/50'"
                >
                  <CheckCircle2 v-if="selectedHabitIds.has(habit.id)" class="h-5 w-5 text-primary-foreground" />
                </div>
              </button>

              <!-- Clickable status indicator (only for today) -->
              <button
                v-if="isToday(currentDate) && !selectionMode"
                @click="handleToggleComplete(habit)"
                class="flex-shrink-0 pt-1 focus:outline-none"
              >
                <div 
                  class="h-10 w-10 rounded-full flex items-center justify-center transition-all hover:scale-110"
                  :style="{ backgroundColor: habit.color + '20' }"
                >
                  <CheckCircle2 
                    v-if="habit.completed_today"
                    class="h-5 w-5"
                    :style="{ color: habit.color }"
                  />
                  <Circle 
                    v-else
                    class="h-5 w-5 text-muted-foreground hover:text-foreground"
                  />
                </div>
              </button>

              <!-- Static status indicator (for non-today) -->
              <div 
                v-if="!isToday(currentDate)"
                class="flex-shrink-0 pt-1"
              >
                <div 
                  class="h-10 w-10 rounded-full flex items-center justify-center"
                  :style="{ backgroundColor: habit.color + '20' }"
                >
                  <Circle class="h-5 w-5 text-muted-foreground" />
                </div>
              </div>

              <!-- Habit info -->
              <div class="flex-1 min-w-0 pt-1">
                <h4 class="font-medium" :class="habit.completed_today && isToday(currentDate) && 'line-through text-muted-foreground'">
                  {{ habit.name }}
                </h4>
                <p v-if="habit.description" class="text-sm text-muted-foreground mt-0.5">
                  {{ habit.description }}
                </p>
                
                <!-- Tags -->
                <div v-if="habit.tags && habit.tags.length > 0" class="flex flex-wrap gap-1.5 mt-2">
                  <Badge 
                    v-for="tag in habit.tags.slice(0, 5)" 
                    :key="tag.id"
                    variant="secondary"
                    class="text-xs"
                  >
                    <div 
                      class="h-2 w-2 rounded-full mr-1.5" 
                      :style="{ backgroundColor: tag.color }"
                    />
                    {{ tag.name }}
                  </Badge>
                </div>
              </div>

              <!-- Edit button (only for today, shows on hover) -->
              <Button 
                v-if="isToday(currentDate) && !selectionMode"
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0"
                @click="emit('edit', habit)"
              >
                <Edit2 class="h-4 w-4" />
              </Button>

              <!-- Status badge -->
              <div class="flex-shrink-0 pt-1" v-if="!selectionMode">
                <Badge 
                  v-if="isToday(currentDate) && habit.completed_today" 
                  variant="default"
                >
                  Completed
                </Badge>
                <Badge 
                  v-else-if="isToday(currentDate)" 
                  variant="outline"
                >
                  Pending
                </Badge>
              </div>
            </div>

            <div 
              v-if="habitsForDay(currentDate).length === 0"
              class="text-center py-16 text-muted-foreground"
            >
              <Circle class="h-12 w-12 mx-auto mb-3 opacity-50" />
              <p class="text-sm">No habits scheduled for this day</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>


  </div>
</template>
