<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { format, startOfMonth, endOfMonth, eachDayOfInterval, isSameMonth, isToday, getDay, startOfWeek, endOfWeek, addDays, subDays } from 'date-fns'
import { isSameDay } from 'date-fns'
import { ChevronLeft, ChevronRight, Plus, TrendingUp, TrendingDown, Wallet, Percent, Settings, Calendar, CalendarDays, CheckCircle2, Trash2 } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
// Card imports removed — no longer used
import { Badge } from '@/components/ui/badge'
import { useBudgetStore } from '@/stores/budget'
import { useCalendarStore } from '@/stores/calendar'
import { formatCurrency } from '@/lib/utils'
import BudgetEntryForm from '@/components/budget/BudgetEntryForm.vue'
import BudgetDayDetail from '@/components/budget/BudgetDayDetail.vue'
import TripCard from '@/components/calendar/TripCard.vue'
import TripDetailModal from '@/components/calendar/TripDetailModal.vue'
// PageHeader removed — using inline toolbar like CalendarView
import FilterDropdown from '@/components/shared/FilterDropdown.vue'
import BaseIconButton from '@/components/shared/BaseIconButton.vue'
import { useReceiptsStore } from '@/stores/receipts'
import type { BudgetEntry } from '@/types'

const budgetStore = useBudgetStore()
const calendarStore = useCalendarStore()
const receiptsStore = useReceiptsStore()
const showEntryForm = ref(false)
const showDayDetail = ref(false)
const inlineDayDetail = ref(false)
const selectedDate = ref<Date | null>(null)
const editingEntry = ref<BudgetEntry | null>(null)

// Trip management state
const selectedTripId = ref<string | null>(null)
const showTripDetail = ref(false)

// Selected day for timeline view (defaults to today)
const selectedDay = ref(new Date())

// Format selected date for display
const formatSelectedDay = computed(() => {
  return format(selectedDay.value, 'EEE, MMM d')
})

// Check if selected day is today
const isSelectedToday = computed(() => {
  return isToday(selectedDay.value)
})

// Day navigation
const goToPreviousDay = () => {
  selectedDay.value = subDays(selectedDay.value, 1)
}

const goToNextDay = () => {
  selectedDay.value = addDays(selectedDay.value, 1)
}

const goToToday = () => {
  selectedDay.value = new Date()
}

// Get entries for the selected day (used by mobile week view)
const selectedDayEntries = computed(() => {
  const dateKey = format(selectedDay.value, 'yyyy-MM-dd')
  return budgetStore.entriesByDate[dateKey] || []
})

// Get trips for the selected day (used by mobile week view)
const selectedDayTrips = computed(() => {
  const dateKey = format(selectedDay.value, 'yyyy-MM-dd')
  return calendarStore.tripsByDate[dateKey] || []
})

// Calculate totals for selected day
const selectedDayIncome = computed(() => {
  return selectedDayEntries.value
    .filter(e => e.type === 'income')
    .reduce((sum, e) => sum + parseFloat(e.amount), 0)
})

const selectedDayExpense = computed(() => {
  return selectedDayEntries.value
    .filter(e => e.type === 'expense')
    .reduce((sum, e) => sum + parseFloat(e.amount), 0)
})

const selectedDayNet = computed(() => selectedDayIncome.value - selectedDayExpense.value)


const calendarDays = computed(() => {
  const days: Date[] = []
  const firstDay = startOfMonth(budgetStore.currentMonth)
  const lastDay = endOfMonth(budgetStore.currentMonth)

  // Get what day of week it is (0 = Sunday, 1 = Monday, etc.)
  let firstDayOfWeek = getDay(firstDay)
  // Adjust for Monday start (0 = Monday, 6 = Sunday)
  firstDayOfWeek = firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1

  // Add padding days from previous month
  for (let i = firstDayOfWeek - 1; i >= 0; i--) {
    days.push(addDays(firstDay, -i - 1))
  }

  // Add all days of the current month
  let currentDay = firstDay
  while (currentDay <= lastDay) {
    days.push(currentDay)
    currentDay = addDays(currentDay, 1)
  }

  // Add padding days from next month to complete the grid (6 rows × 7 columns = 42)
  const remainingDays = 42 - days.length
  for (let i = 1; i <= remainingDays; i++) {
    days.push(addDays(lastDay, i))
  }

  return days
})

// Weekly view days
const weekDays = computed(() => {
  const start = startOfWeek(budgetStore.currentWeek, { weekStartsOn: 1 })
  const end = endOfWeek(budgetStore.currentWeek, { weekStartsOn: 1 })
  return eachDayOfInterval({ start, end })
})

const filterTags = ref<Set<string>>(new Set())

// Sync filter tags from store
watch(() => budgetStore.filterTags, (newTags) => {
  filterTags.value = new Set(newTags)
}, { immediate: true })

const handleFilterApply = async () => {
  budgetStore.filterTags = Array.from(filterTags.value)
  await Promise.all([
    budgetStore.fetchCurrentViewEntries(),
    budgetStore.fetchSummary()
  ])
}

const handleFilterClear = async () => {
  budgetStore.filterTags = []
  filterTags.value = new Set()
  await Promise.all([
    budgetStore.fetchCurrentViewEntries(),
    budgetStore.fetchSummary()
  ])
}

onMounted(async () => {
  // Reset filters
  budgetStore.filterTags = []
  // Fetch trips for the current visible period
  const start = startOfWeek(budgetStore.currentWeek, { weekStartsOn: 1 })
  const end = endOfWeek(budgetStore.currentWeek, { weekStartsOn: 1 })
  await Promise.all([
    budgetStore.fetchSources(),
    budgetStore.fetchMonthEntries(),
    budgetStore.fetchSummary(),
    calendarStore.fetchTripsForPeriod(start, end)
  ])
})

const getDayEntries = (date: Date) => {
  const dateKey = format(date, 'yyyy-MM-dd')
  return budgetStore.entriesByDate[dateKey] || []
}

const getDayTotal = (date: Date, type: 'income' | 'expense') => {
  const entries = getDayEntries(date)
  return entries
    .filter(e => e.type === type)
    .reduce((sum, e) => sum + parseFloat(e.amount), 0)
}

// Get net for a day (income - expense)
const getDayNet = (date: Date) => {
  return getDayTotal(date, 'income') - getDayTotal(date, 'expense')
}

// Get recent entries for mobile view
const recentEntries = computed(() => {
  const entries = Object.values(budgetStore.entriesByDate).flat()
  return entries.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()).slice(0, 10)
})

// Get all trips for the current period (for mobile month view)
const allTrips = computed(() => {
  const trips = Object.values(calendarStore.tripsByDate).flat()
  return trips.sort((a, b) => {
    const dateA = a.trip_start ? new Date(a.trip_start).getTime() : 0
    const dateB = b.trip_start ? new Date(b.trip_start).getTime() : 0
    return dateB - dateA
  })
})

const openDayDetail = (date: Date) => {
  selectedDate.value = date
  // Desktop: inline popout within the calendar grid
  // Mobile: full modal
  if (window.innerWidth >= 640) {
    inlineDayDetail.value = true
    showDayDetail.value = false
  } else {
    showDayDetail.value = true
    inlineDayDetail.value = false
  }
}

const closeInlineDayDetail = () => {
  inlineDayDetail.value = false
  selectedDate.value = null
}

const openNewEntry = (date?: Date) => {
  selectedDate.value = date || new Date()
  editingEntry.value = null
  showDayDetail.value = false
  inlineDayDetail.value = false
  showEntryForm.value = true
}

const openEditEntry = (entry: BudgetEntry) => {
  editingEntry.value = entry
  showDayDetail.value = false
  inlineDayDetail.value = false
  showEntryForm.value = true
}

const refreshData = async () => {
  // Determine date range based on current view
  const start = budgetStore.viewMode === 'week' 
    ? startOfWeek(budgetStore.currentWeek, { weekStartsOn: 1 })
    : startOfMonth(budgetStore.currentMonth)
  const end = budgetStore.viewMode === 'week'
    ? endOfWeek(budgetStore.currentWeek, { weekStartsOn: 1 })
    : endOfMonth(budgetStore.currentMonth)
  
  await Promise.all([
    budgetStore.fetchCurrentViewEntries(), // Use current view instead of hardcoded month
    budgetStore.fetchSummary(),
    calendarStore.fetchTripsForPeriod(start, end)
  ])
}

// Trip handlers
const handleTripClick = (tripId: string) => {
  selectedTripId.value = tripId
  showTripDetail.value = true
}

const handleTripDelete = async (tripId: string) => {
  await receiptsStore.deleteTrip(tripId)
  await refreshData()
}

const handleTripDetailClose = async () => {
  showTripDetail.value = false
  selectedTripId.value = null
  await refreshData() // Refresh in case purchases were changed
}
</script>

<template>
  <div class="h-[calc(100vh-48px)] flex flex-col animate-fade-in relative overflow-hidden">
    <!-- Single-row toolbar (matches CalendarView) -->
    <div class="flex items-center gap-2 mb-2">
      <!-- Budget label (borderless pill) -->
      <div class="flex items-center gap-1.5 h-9 px-3 rounded-lg">
        <Wallet class="h-4 w-4 text-primary" />
        <span class="text-sm font-bold tracking-tight">Budget</span>
      </div>

      <!-- Date range text (borderless pill) -->
      <div class="h-9 flex items-center px-3 rounded-lg">
        <span class="text-sm text-muted-foreground">
          <template v-if="budgetStore.viewMode === 'month'">{{ format(budgetStore.currentMonth, 'MMMM yyyy') }}</template>
          <template v-else>{{ format(weekDays[0], 'MMM d') }} – {{ format(weekDays[6], 'MMM d, yyyy') }}</template>
        </span>
      </div>

      <!-- Summary badges (compact inline) -->
      <div class="hidden sm:flex items-center gap-1.5">
        <Badge variant="secondary" class="text-[11px] h-7 px-2 bg-emerald-500/10 text-emerald-600 border-0 gap-1 tabular-nums">
          <TrendingUp class="h-3 w-3" />
          {{ budgetStore.summary ? formatCurrency(budgetStore.summary.income) : '$0' }}
        </Badge>
        <Badge variant="secondary" class="text-[11px] h-7 px-2 bg-red-500/10 text-red-500 border-0 gap-1 tabular-nums">
          <TrendingDown class="h-3 w-3" />
          {{ budgetStore.summary ? formatCurrency(budgetStore.summary.expense) : '$0' }}
        </Badge>
        <Badge 
          variant="secondary" 
          :class="'text-[11px] h-7 px-2 border-0 gap-1 tabular-nums ' + (budgetStore.summary && parseFloat(budgetStore.summary.net) >= 0 ? 'bg-emerald-500/15 text-emerald-600' : 'bg-red-500/15 text-red-500')"
        >
          <Wallet class="h-3 w-3" />
          {{ budgetStore.summary ? formatCurrency(budgetStore.summary.net) : '$0' }}
        </Badge>
        <Badge variant="secondary" class="text-[11px] h-7 px-2 bg-violet-500/10 text-violet-600 border-0 gap-1 tabular-nums">
          <Percent class="h-3 w-3" />
          {{ budgetStore.summary?.savings_rate || '0' }}%
        </Badge>
      </div>

      <div class="flex-1" />

      <!-- Navigation with View Toggle (matches CalendarView pattern) -->
      <div class="flex items-center rounded-lg border border-border bg-card overflow-hidden">
        <Button variant="ghost" size="icon" class="rounded-none h-9 w-9" @click="budgetStore.viewMode === 'week' ? budgetStore.prevWeek() : budgetStore.prevMonth(); refreshData()" title="Previous">
          <ChevronLeft class="h-4 w-4" />
        </Button>
        <div class="w-px h-5 bg-border" />
        <Button 
          :variant="budgetStore.viewMode === 'week' ? 'default' : 'ghost'" 
          size="sm" 
          class="rounded-none h-9 px-3 gap-1.5"
          @click="budgetStore.viewMode !== 'week' && (budgetStore.toggleViewMode(), budgetStore.fetchWeekEntries())"
        >
          <Calendar class="h-4 w-4" />
          <span class="hidden sm:inline text-[13px]">Week</span>
        </Button>
        <div class="w-px h-5 bg-border" />
        <Button 
          :variant="budgetStore.viewMode === 'month' ? 'default' : 'ghost'" 
          size="sm" 
          class="rounded-none h-9 px-3 gap-1.5"
          @click="budgetStore.viewMode !== 'month' && (budgetStore.toggleViewMode(), budgetStore.fetchMonthEntries())"
        >
          <CalendarDays class="h-4 w-4" />
          <span class="hidden sm:inline text-[13px]">Month</span>
        </Button>
        <div class="w-px h-5 bg-border" />
        <Button variant="ghost" size="icon" class="rounded-none h-9 w-9" @click="budgetStore.viewMode === 'week' ? budgetStore.nextWeek() : budgetStore.nextMonth(); refreshData()" title="Next">
          <ChevronRight class="h-4 w-4" />
        </Button>
      </div>

      <!-- Filter -->
      <FilterDropdown
        v-model="filterTags"
        title="Filter Entries"
        @apply="handleFilterApply"
        @clear="handleFilterClear"
      />

      <!-- Manage Sources -->
      <Button variant="outline" size="sm" class="h-9 gap-1.5 shrink-0" @click="$router.push('/budget/sources')">
        <Settings class="h-4 w-4" />
        <span class="hidden sm:inline">Sources</span>
      </Button>

      <!-- Add Entry -->
      <Button variant="outline" size="sm" class="h-9 gap-1.5 shrink-0" @click="openNewEntry()" data-testid="add-button">
        <Plus class="h-4 w-4" />
        <span class="hidden sm:inline">Add Entry</span>
      </Button>
    </div>

    <!-- Calendar Grid - Desktop (Month View) -->
    <div v-if="budgetStore.viewMode === 'month'" class="hidden sm:flex flex-1 min-h-0 flex-col rounded-xl border border-white/[0.08] bg-gradient-to-br from-card to-card/95 overflow-hidden shadow-lg shadow-black/5 relative">
      <!-- Inline Day Detail Overlay (spans entire grid) -->
      <div 
        v-if="inlineDayDetail && selectedDate"
        class="absolute inset-0 z-30 bg-card border border-white/[0.12] rounded-lg overflow-hidden"
      >
        <BudgetDayDetail
          :date="selectedDate"
          :inline-mode="true"
          class="h-full"
          @close="closeInlineDayDetail"
          @add-entry="openNewEntry(selectedDate!)"
          @edit-entry="openEditEntry"
          @refresh="refreshData()"
        />
      </div>

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
          v-for="(day, dayIndex) in calendarDays"
          :key="day.toISOString()"
          :class="[
            'group relative flex flex-col min-h-[110px] transition-all duration-200',
            'border-r border-b border-border',
            isToday(day) 
              ? 'bg-primary/[0.06] ring-1 ring-inset ring-primary/20' 
              : !isSameMonth(day, budgetStore.currentMonth)
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
            <button
              :class="[
                'inline-flex items-center justify-center font-semibold transition-all',
                isToday(day) 
                  ? 'h-7 w-7 rounded-full bg-primary text-primary-foreground text-sm shadow-lg shadow-primary/30' 
                  : !isSameMonth(day, budgetStore.currentMonth)
                    ? 'text-muted-foreground/30 text-sm'
                    : 'text-foreground/90 text-sm'
              ]"
              @click="openDayDetail(day)"
            >
              {{ format(day, 'd') }}
            </button>

            <!-- Add entry button on hover -->
            <button
              v-if="isSameMonth(day, budgetStore.currentMonth)"
              class="opacity-0 group-hover:opacity-100 focus:opacity-100 text-muted-foreground/60 hover:text-primary transition-all h-5 w-5 flex items-center justify-center rounded hover:bg-primary/10"
              @click="openNewEntry(day)"
            >
              <Plus class="h-3 w-3" />
            </button>
          </div>

          <!-- Day Content -->
          <div class="flex-1 px-1.5 py-1 space-y-0.5 overflow-hidden relative">
            <!-- Trips in month view -->
            <TripCard
              v-for="trip in calendarStore.tripsByDate[format(day, 'yyyy-MM-dd')] || []"
              :key="trip.id"
              :trip="trip"
              :compact="true"
              @click="handleTripClick"
              @delete="handleTripDelete"
            />

            <button 
              v-if="getDayNet(day) !== 0"
              class="w-full text-left hover:bg-secondary/50 rounded p-0.5 -mx-0.5 transition-colors"
              @click="openDayDetail(day)"
            >
              <div 
                :class="[
                  'text-[11px] font-semibold tabular-nums',
                  getDayNet(day) > 0 ? 'text-emerald-600' : 'text-red-500'
                ]"
              >
                {{ getDayNet(day) > 0 ? '+' : '' }}{{ formatCurrency(getDayNet(day)) }}
              </div>
            </button>

            <!-- Empty state hover indicator -->
            <div 
              v-if="getDayNet(day) === 0 && (calendarStore.tripsByDate[format(day, 'yyyy-MM-dd')] || []).length === 0 && isSameMonth(day, budgetStore.currentMonth)"
              class="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
            >
              <div class="w-8 h-8 rounded-full bg-white/[0.03] flex items-center justify-center border border-dashed border-white/[0.08]">
                <Plus class="h-4 w-4 text-muted-foreground/40" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Desktop Week Calendar Grid (matches CalendarView) -->
    <div v-if="budgetStore.viewMode === 'week'" class="hidden sm:flex flex-1 min-h-0 flex-col rounded-xl border border-white/[0.08] bg-gradient-to-br from-card to-card/95 overflow-hidden shadow-lg shadow-black/5 relative">
      <!-- Inline Day Detail Overlay (week mode) -->
      <div 
        v-if="inlineDayDetail && selectedDate"
        class="absolute inset-0 z-30 bg-card border border-white/[0.12] rounded-xl overflow-hidden"
      >
        <BudgetDayDetail
          :date="selectedDate"
          :inline-mode="true"
          class="h-full"
          @close="closeInlineDayDetail"
          @add-entry="openNewEntry(selectedDate!)"
          @edit-entry="openEditEntry"
          @refresh="refreshData()"
        />
      </div>

      <!-- Day of week headers -->
      <div class="grid grid-cols-7 bg-gradient-to-b from-white/[0.04] to-transparent border-b border-border">
        <div 
          v-for="(day, index) in weekDays" 
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
        <div
          v-for="(day, dayIndex) in weekDays"
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
            <!-- Day net summary -->
            <button 
              v-if="getDayNet(day) !== 0"
              class="w-full text-left hover:bg-secondary/50 rounded p-0.5 -mx-0.5 transition-colors mb-1"
              @click="openDayDetail(day)"
            >
              <div 
                :class="[
                  'text-[11px] font-semibold tabular-nums',
                  getDayNet(day) > 0 ? 'text-emerald-600' : 'text-red-500'
                ]"
              >
                {{ getDayNet(day) > 0 ? '+' : '' }}{{ formatCurrency(getDayNet(day)) }}
              </div>
            </button>

            <!-- Trips in week view -->
            <TripCard
              v-for="trip in calendarStore.tripsByDate[format(day, 'yyyy-MM-dd')] || []"
              :key="trip.id"
              :trip="trip"
              :compact="true"
              @click="handleTripClick"
              @delete="handleTripDelete"
            />

            <!-- Budget entries -->
            <div 
              v-for="entry in getDayEntries(day)" 
              :key="entry.id"
              :class="[
                'flex items-center gap-1.5 p-1.5 rounded-lg cursor-pointer transition-all hover:bg-white/[0.06]',
                'border-l-2',
                entry.type === 'income' ? 'border-l-emerald-500' : 'border-l-red-500'
              ]"
              @click="openEditEntry(entry)"
            >
              <component 
                :is="entry.type === 'income' ? TrendingUp : TrendingDown" 
                :class="[
                  'h-3 w-3 shrink-0',
                  entry.type === 'income' ? 'text-emerald-600' : 'text-red-500'
                ]" 
              />
              <span class="text-[11px] font-medium truncate flex-1 min-w-0">{{ entry.source?.name || 'Entry' }}</span>
              <span 
                :class="[
                  'text-[11px] font-semibold tabular-nums shrink-0',
                  entry.type === 'income' ? 'text-emerald-600' : 'text-red-500'
                ]"
              >
                {{ entry.type === 'income' ? '+' : '' }}{{ formatCurrency(entry.amount) }}
              </span>
            </div>
          </div>

          <!-- Add entry button on hover -->
          <button
            :class="[
              'opacity-0 group-hover:opacity-100 absolute bottom-3 right-3 h-8 w-8 rounded-full flex items-center justify-center transition-all duration-200 z-10',
              'bg-primary/20 hover:bg-primary/30 hover:scale-110',
              'shadow-lg shadow-primary/10'
            ]"
            @click.stop="openNewEntry(day)"
          >
            <Plus class="h-4 w-4 text-primary" />
          </button>
        </div>
      </div>
    </div>

    <!-- Calendar Grid - Mobile (Month View) -->
    <div v-if="budgetStore.viewMode === 'month'" class="sm:hidden border border-border/80 rounded-xl overflow-hidden bg-card">
      <div class="grid grid-cols-7 bg-secondary/40">
        <div v-for="day in ['M', 'T', 'W', 'T', 'F', 'S', 'S']" :key="day" class="p-1.5 text-center text-[10px] font-semibold text-muted-foreground">
          {{ day }}
        </div>
      </div>
      
      <div class="grid grid-cols-7">
        <button
          v-for="(day, index) in calendarDays"
          :key="day.toISOString()"
          :class="[
            'min-h-[52px] border-t border-r border-border p-1 last:border-r-0 [&:nth-child(7n)]:border-r-0 flex flex-col items-center transition-colors',
            isToday(day) && 'bg-primary/[0.03]',
            isSameMonth(day, budgetStore.currentMonth) && (getDayTotal(day, 'income') > 0 || getDayTotal(day, 'expense') > 0) && 'active:bg-secondary/60',
            !isSameMonth(day, budgetStore.currentMonth) && 'bg-secondary/20'
          ]"
          @click="openDayDetail(day)"
        >
          <span :class="[
            'inline-flex items-center justify-center text-xs font-medium w-6 h-6 mb-0.5',
            isToday(day) ? 'rounded-full bg-primary text-primary-foreground' 
              : !isSameMonth(day, budgetStore.currentMonth) ? 'text-muted-foreground/40'
              : 'text-foreground'
          ]">
            {{ format(day, 'd') }}
          </span>
          <div v-if="isSameMonth(day, budgetStore.currentMonth)" class="flex flex-col items-center gap-0.5">
            <span 
              v-if="getDayTotal(day, 'income') > 0"
              class="w-1.5 h-1.5 rounded-full bg-emerald-500"
            />
            <span 
              v-if="getDayTotal(day, 'expense') > 0"
              class="w-1.5 h-1.5 rounded-full bg-red-500"
            />
          </div>
        </button>
      </div>
    </div>

    <!-- Budget Timeline View - Mobile (Week Mode) - Habits Style -->
    <div v-if="budgetStore.viewMode === 'week'" class="sm:hidden space-y-3">
      <!-- Day Navigation Controls (Mobile) -->
      <div class="flex items-center justify-center gap-2 bg-card/50 rounded-lg px-3 py-2 border border-border/50">
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-8 w-8"
          @click="goToPreviousDay"
        >
          <ChevronLeft class="h-4 w-4" />
        </Button>
        <div class="flex flex-col items-center min-w-[100px]">
          <span class="text-sm font-medium">{{ formatSelectedDay }}</span>
        </div>
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-8 w-8"
          @click="goToNextDay"
        >
          <ChevronRight class="h-4 w-4" />
        </Button>
        <Button 
          variant="outline" 
          size="sm" 
          class="h-7 text-xs ml-1"
          :class="isSelectedToday ? 'opacity-0 pointer-events-none' : ''"
          @click="goToToday"
        >
          Today
        </Button>
      </div>

      <!-- Day Summary Header (Mobile) -->
      <div class="flex items-center gap-2 px-2 flex-wrap">
        <div class="w-2.5 h-2.5 rounded-full bg-primary" />
        <span class="font-semibold text-sm">{{ format(selectedDay, 'EEEE') }}</span>
        <span class="text-xs text-muted-foreground">({{ selectedDayEntries.length + selectedDayTrips.length }})</span>
        
        <Badge v-if="selectedDayIncome > 0" variant="secondary" class="text-[10px] h-5 px-1.5 bg-emerald-500/10 text-emerald-700 border-0">
          +{{ formatCurrency(selectedDayIncome) }}
        </Badge>
        <Badge v-if="selectedDayExpense > 0" variant="secondary" class="text-[10px] h-5 px-1.5 bg-red-500/10 text-red-600 border-0">
          -{{ formatCurrency(selectedDayExpense) }}
        </Badge>
      </div>

      <!-- Entry Cards (Mobile) -->
      <div class="space-y-2">
        <!-- Trips with purchases (Mobile) -->
        <div 
          v-for="trip in selectedDayTrips" 
          :key="'mobile-trip-' + trip.id"
          class="p-3 rounded-xl bg-card border border-border/60 border-l-[3px] border-l-blue-500"
        >
          <!-- Trip Header -->
          <div class="flex items-center gap-2">
            <div class="h-7 w-7 rounded bg-blue-500/10 flex items-center justify-center shrink-0">
              <Calendar class="h-3.5 w-3.5 text-blue-600" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium truncate">
                {{ trip.stops?.[0]?.store_name || 'Shopping Trip' }}
              </p>
              <p class="text-[10px] text-muted-foreground">
                {{ trip.stops?.flatMap(s => s.purchases || []).length || 0 }} items
              </p>
            </div>
            <span class="text-sm font-semibold tabular-nums text-red-500">
              -{{ formatCurrency(trip.stops?.flatMap(s => s.purchases || []).reduce((sum, p) => sum + parseFloat(p.total_price || '0'), 0) || 0) }}
            </span>
            <!-- Delete button (always visible on mobile) -->
            <BaseIconButton :icon="Trash2" variant="destructive" :adaptive="false" @click.stop="handleTripDelete(trip.id)" />
          </div>

          <!-- Purchases list - indented -->
          <div 
            v-if="trip.stops?.some(s => s.purchases && s.purchases.length > 0)"
            class="ml-9 mt-2 space-y-1 border-l-2 border-border/40 pl-2"
          >
            <div 
              v-for="purchase in trip.stops?.flatMap(s => s.purchases || []) || []" 
              :key="'mobile-purchase-' + purchase.id"
              class="flex items-center justify-between text-xs py-0.5"
            >
              <div class="flex items-center gap-1 min-w-0 flex-1">
                <span class="text-muted-foreground truncate max-w-[80px]">{{ purchase.brand }}</span>
                <span class="truncate text-foreground/80">{{ purchase.item }}</span>
                <span v-if="purchase.count" class="text-muted-foreground shrink-0 text-[10px]">x{{ purchase.count }}</span>
              </div>
              <span class="text-red-500 font-medium tabular-nums shrink-0 ml-2">
                {{ formatCurrency(purchase.total_price) }}
              </span>
            </div>
          </div>
        </div>

        <!-- Budget Entries -->
        <div 
          v-for="entry in selectedDayEntries" 
          :key="'mobile-' + entry.id"
          class="flex items-center justify-between p-3 rounded-xl bg-card border border-border/60"
          @click="openEditEntry(entry)"
        >
          <div class="flex items-center gap-3">
            <div :class="[
              'h-8 w-8 rounded-lg flex items-center justify-center',
              entry.type === 'income' ? 'bg-emerald-500/10' : 'bg-red-500/10'
            ]">
              <component 
                :is="entry.type === 'income' ? TrendingUp : TrendingDown" 
                :class="[
                  'h-4 w-4',
                  entry.type === 'income' ? 'text-emerald-600' : 'text-red-500'
                ]" 
              />
            </div>
            <div>
              <p class="text-sm font-medium">{{ entry.source?.name || 'No source' }}</p>
              <p v-if="entry.notes" class="text-xs text-muted-foreground truncate max-w-[150px]">{{ entry.notes }}</p>
            </div>
          </div>
          <span :class="[
            'text-sm font-semibold tabular-nums',
            entry.type === 'income' ? 'text-emerald-600' : 'text-red-500'
          ]">
            {{ entry.type === 'income' ? '+' : '-' }}{{ formatCurrency(entry.amount) }}
          </span>
        </div>

        <!-- Empty State -->
        <div v-if="selectedDayEntries.length === 0 && selectedDayTrips.length === 0" class="text-center py-8">
          <div class="h-12 w-12 rounded-xl bg-muted/30 mx-auto mb-3 flex items-center justify-center">
            <Wallet class="h-6 w-6 text-muted-foreground/50" />
          </div>
          <p class="text-sm text-muted-foreground">No entries for this day</p>
          <Button variant="outline" size="sm" class="mt-3" @click="openNewEntry(selectedDay)">
            <Plus class="h-3 w-3 mr-1" />
            Add Entry
          </Button>
        </div>
      </div>
    </div>

    <!-- Mobile: Shopping Trips (Month View) -->
    <div v-if="budgetStore.viewMode === 'month' && allTrips.length > 0" class="sm:hidden space-y-2">
      <h3 class="text-sm font-medium text-muted-foreground">Shopping Trips</h3>
      <div class="space-y-2">
        <div 
          v-for="trip in allTrips" 
          :key="'mobile-month-trip-' + trip.id"
          class="flex items-center justify-between p-3 rounded-xl bg-card border border-border/60 border-l-[3px] border-l-emerald-500"
          @click="handleTripClick(trip.id)"
        >
          <div class="flex items-center gap-3">
            <div class="h-8 w-8 rounded-lg bg-emerald-500/10 flex items-center justify-center">
              <Calendar class="h-4 w-4 text-emerald-600" />
            </div>
            <div>
              <p class="text-sm font-medium">{{ trip.stops?.[0]?.store_name || 'Shopping Trip' }}</p>
              <p class="text-xs text-muted-foreground">
                {{ trip.trip_start ? format(new Date(trip.trip_start), 'MMM d') : 'No date' }} · 
                {{ trip.stops?.flatMap(s => s.purchases || []).length || 0 }} items
              </p>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-sm font-semibold tabular-nums text-red-500">
              -{{ formatCurrency(trip.stops?.flatMap(s => s.purchases || []).reduce((sum, p) => sum + parseFloat(p.total_price || '0'), 0) || 0) }}
            </span>
            <BaseIconButton :icon="Trash2" variant="destructive" :adaptive="false" @click.stop="handleTripDelete(trip.id)" />
          </div>
        </div>
      </div>
    </div>

    <!-- Mobile: Recent Entries List -->
    <div class="sm:hidden space-y-2">
      <h3 class="text-sm font-medium text-muted-foreground">Recent entries this {{ budgetStore.viewMode === 'week' ? 'week' : 'month' }}</h3>
      <div class="space-y-2">
        <div 
          v-for="entry in recentEntries" 
          :key="entry.id"
          class="flex items-center justify-between p-3 rounded-xl bg-card border border-border/60"
        >
          <div class="flex items-center gap-3">
            <div :class="[
              'h-8 w-8 rounded-lg flex items-center justify-center',
              entry.type === 'income' ? 'bg-emerald-500/10' : 'bg-red-500/10'
            ]">
              <component 
                :is="entry.type === 'income' ? TrendingUp : TrendingDown" 
                :class="[
                  'h-4 w-4',
                  entry.type === 'income' ? 'text-emerald-600' : 'text-red-500'
                ]" 
              />
            </div>
            <div>
              <p class="text-sm font-medium">{{ entry.source?.name || 'No source' }}</p>
              <p class="text-xs text-muted-foreground">{{ format(new Date(entry.date), 'MMM d') }}</p>
            </div>
          </div>
          <span :class="[
            'text-sm font-semibold tabular-nums',
            entry.type === 'income' ? 'text-emerald-600' : 'text-red-500'
          ]">
            {{ entry.type === 'income' ? '+' : '-' }}{{ formatCurrency(entry.amount) }}
          </span>
        </div>
        <div v-if="recentEntries.length === 0" class="text-center py-8 text-muted-foreground text-sm">
          No entries this month
        </div>
      </div>
    </div>

    <!-- Mobile-only modal day detail -->
    <BudgetDayDetail
      v-if="showDayDetail && selectedDate"
      :date="selectedDate"
      @close="showDayDetail = false"
      @add-entry="openNewEntry(selectedDate!)"
      @edit-entry="openEditEntry"
      @refresh="refreshData()"
    />

    <BudgetEntryForm
      v-if="showEntryForm"
      :initial-date="selectedDate"
      :entry="editingEntry"
      @close="showEntryForm = false; editingEntry = null"
      @saved="showEntryForm = false; editingEntry = null; refreshData()"
    />

    <!-- Trip Detail Modal -->
    <TripDetailModal
      v-if="showTripDetail && selectedTripId"
      :trip-id="selectedTripId"
      @close="handleTripDetailClose"
    />
  </div>
</template>
