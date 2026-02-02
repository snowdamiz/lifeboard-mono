<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { format, startOfMonth, endOfMonth, eachDayOfInterval, isSameMonth, isToday, getDay, startOfWeek, endOfWeek, addDays, subDays } from 'date-fns'
import { ChevronLeft, ChevronRight, Plus, TrendingUp, TrendingDown, Wallet, Percent, Settings, Calendar, CalendarDays, CheckCircle2 } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { useBudgetStore } from '@/stores/budget'
import { useCalendarStore } from '@/stores/calendar'
import { formatCurrency } from '@/lib/utils'
import BudgetEntryForm from '@/components/budget/BudgetEntryForm.vue'
import BudgetDayDetail from '@/components/budget/BudgetDayDetail.vue'
import TripCard from '@/components/calendar/TripCard.vue'
import TripDetailModal from '@/components/calendar/TripDetailModal.vue'
import PageHeader from '@/components/shared/PageHeader.vue'
import FilterDropdown from '@/components/shared/FilterDropdown.vue'
import DeleteButton from '@/components/shared/DeleteButton.vue'
import { useReceiptsStore } from '@/stores/receipts'
import type { BudgetEntry } from '@/types'

const budgetStore = useBudgetStore()
const calendarStore = useCalendarStore()
const receiptsStore = useReceiptsStore()
const showEntryForm = ref(false)
const showDayDetail = ref(false)
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

// Timeline settings
const timelineScale = ref(3) // pixels per minute
const MIN_SCALE = 1
const MAX_SCALE = 10

// Get entries for the selected day
const selectedDayEntries = computed(() => {
  const dateKey = format(selectedDay.value, 'yyyy-MM-dd')
  return budgetStore.entriesByDate[dateKey] || []
})

// Get trips for the selected day
const selectedDayTrips = computed(() => {
  const dateKey = format(selectedDay.value, 'yyyy-MM-dd')
  return calendarStore.tripsByDate[dateKey] || []
})

// Timeline hours for the view (6am to 10pm default, or based on entries)
const timelineHours = computed(() => {
  const hours: number[] = []
  // Start from 6am to 10pm
  for (let h = 6; h <= 22; h++) {
    hours.push(h * 60) // Convert to minutes
  }
  return hours
})

const timelineStartMins = computed(() => 6 * 60) // 6am
const timelineEndMins = computed(() => 22 * 60) // 10pm
const timelineHeight = computed(() => (timelineEndMins.value - timelineStartMins.value) * timelineScale.value)

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
  const start = startOfMonth(budgetStore.currentMonth)
  const end = endOfMonth(budgetStore.currentMonth)
  const days = eachDayOfInterval({ start, end })
  
  // Add padding for first week (before month starts)
  const startDay = getDay(start)
  const leadingPadding = Array(startDay === 0 ? 6 : startDay - 1).fill(null)
  
  // Always render exactly 42 cells (6 rows × 7 columns) for consistent height
  const totalCells = 42
  const filledCells = leadingPadding.length + days.length
  const trailingPadding = Array(Math.max(0, totalCells - filledCells)).fill(null)
  
  return [...leadingPadding, ...days, ...trailingPadding]
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
  showDayDetail.value = true
}

const openNewEntry = (date?: Date) => {
  selectedDate.value = date || new Date()
  editingEntry.value = null
  showDayDetail.value = false
  showEntryForm.value = true
}

const openEditEntry = (entry: BudgetEntry) => {
  editingEntry.value = entry
  showDayDetail.value = false
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
  <div class="space-y-4 sm:space-y-6 animate-fade-in pb-20 sm:pb-0">
    <!-- Header -->
    <PageHeader :icon="Wallet" title="Budget" subtitle="Track income and expenses">
      <template #actions>
        <FilterDropdown
          v-model="filterTags"
          title="Filter Entries"
          @apply="handleFilterApply"
          @clear="handleFilterClear"
        />
        <Button variant="outline" size="sm" class="flex-1 sm:flex-none text-xs sm:text-sm" @click="$router.push('/budget/sources')">
          <Settings class="h-4 w-4 sm:mr-2" />
          <span class="hidden sm:inline">Manage Sources</span>
          <span class="sm:hidden">Sources</span>
        </Button>
        <Button size="sm" class="flex-1 sm:flex-none text-xs sm:text-sm" @click="openNewEntry()">
          <Plus class="h-4 w-4 sm:mr-2" />
          <span class="hidden sm:inline">Add Entry</span>
          <span class="sm:hidden">Add</span>
        </Button>
      </template>
    </PageHeader>

    <!-- Summary Cards -->
    <div class="grid gap-3 sm:gap-4 grid-cols-2 lg:grid-cols-4">
      <Card class="touch-manipulation">
        <CardHeader class="flex flex-row items-center justify-between pb-1.5 sm:pb-2 p-3 sm:p-4">
          <CardTitle class="text-[11px] sm:text-[13px] font-medium text-muted-foreground">Income</CardTitle>
          <div class="h-7 w-7 sm:h-9 sm:w-9 rounded-lg bg-emerald-500/10 flex items-center justify-center">
            <TrendingUp class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-emerald-600" />
          </div>
        </CardHeader>
        <CardContent class="p-3 pt-0 sm:p-4 sm:pt-0">
          <div class="text-xl sm:text-2xl font-semibold text-emerald-600 tabular-nums">
            {{ budgetStore.summary ? formatCurrency(budgetStore.summary.income) : '$0' }}
          </div>
        </CardContent>
      </Card>

      <Card class="touch-manipulation">
        <CardHeader class="flex flex-row items-center justify-between pb-1.5 sm:pb-2 p-3 sm:p-4">
          <CardTitle class="text-[11px] sm:text-[13px] font-medium text-muted-foreground">Expenses</CardTitle>
          <div class="h-7 w-7 sm:h-9 sm:w-9 rounded-lg bg-red-500/10 flex items-center justify-center">
            <TrendingDown class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-red-500" />
          </div>
        </CardHeader>
        <CardContent class="p-3 pt-0 sm:p-4 sm:pt-0">
          <div class="text-xl sm:text-2xl font-semibold text-red-500 tabular-nums">
            {{ budgetStore.summary ? formatCurrency(budgetStore.summary.expense) : '$0' }}
          </div>
        </CardContent>
      </Card>

      <Card class="touch-manipulation">
        <CardHeader class="flex flex-row items-center justify-between pb-1.5 sm:pb-2 p-3 sm:p-4">
          <CardTitle class="text-[11px] sm:text-[13px] font-medium text-muted-foreground">Net</CardTitle>
          <div class="h-7 w-7 sm:h-9 sm:w-9 rounded-lg bg-primary/10 flex items-center justify-center">
            <Wallet class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-primary" />
          </div>
        </CardHeader>
        <CardContent class="p-3 pt-0 sm:p-4 sm:pt-0">
          <div :class="[
            'text-xl sm:text-2xl font-semibold tabular-nums',
            budgetStore.summary && parseFloat(budgetStore.summary.net) >= 0 ? 'text-emerald-600' : 'text-red-500'
          ]">
            {{ budgetStore.summary ? formatCurrency(budgetStore.summary.net) : '$0' }}
          </div>
        </CardContent>
      </Card>

      <Card class="touch-manipulation">
        <CardHeader class="flex flex-row items-center justify-between pb-1.5 sm:pb-2 p-3 sm:p-4">
          <CardTitle class="text-[11px] sm:text-[13px] font-medium text-muted-foreground">Savings Rate</CardTitle>
          <div class="h-7 w-7 sm:h-9 sm:w-9 rounded-lg bg-violet-500/10 flex items-center justify-center">
            <Percent class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-violet-600" />
          </div>
        </CardHeader>
        <CardContent class="p-3 pt-0 sm:p-4 sm:pt-0">
          <div class="text-xl sm:text-2xl font-semibold tabular-nums">
            {{ budgetStore.summary?.savings_rate || '0' }}%
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Calendar Navigation -->
    <div class="flex items-center justify-between gap-2">
      <h2 class="text-base sm:text-lg font-medium">
        <template v-if="budgetStore.viewMode === 'month'">
          {{ format(budgetStore.currentMonth, 'MMMM yyyy') }}
        </template>
        <template v-else>
          {{ format(weekDays[0], 'MMM d') }} – {{ format(weekDays[6], 'MMM d, yyyy') }}
        </template>
      </h2>
      
      <div class="flex items-center gap-2">
        <!-- View Toggle -->
        <div class="flex items-center rounded-lg border border-border bg-card overflow-hidden">
          <Button 
            :variant="budgetStore.viewMode === 'week' ? 'default' : 'ghost'" 
            size="sm" 
            class="rounded-none h-8 sm:h-9 px-2 sm:px-3 gap-1"
            @click="budgetStore.viewMode !== 'week' && (budgetStore.toggleViewMode(), budgetStore.fetchWeekEntries())"
          >
            <Calendar class="h-3.5 w-3.5" />
            <span class="hidden sm:inline text-xs">Week</span>
          </Button>
          <div class="w-px h-5 bg-border" />
          <Button 
            :variant="budgetStore.viewMode === 'month' ? 'default' : 'ghost'" 
            size="sm" 
            class="rounded-none h-8 sm:h-9 px-2 sm:px-3 gap-1"
            @click="budgetStore.viewMode !== 'month' && (budgetStore.toggleViewMode(), budgetStore.fetchMonthEntries())"
          >
            <CalendarDays class="h-3.5 w-3.5" />
            <span class="hidden sm:inline text-xs">Month</span>
          </Button>
        </div>

        <!-- Navigation -->
        <div class="flex items-center rounded-lg border border-border bg-card overflow-hidden">
          <Button variant="ghost" size="sm" class="rounded-none px-2 sm:px-3 h-8 sm:h-9 text-xs" @click="budgetStore.viewMode === 'week' ? budgetStore.goToTodayWeek() : budgetStore.setCurrentMonth(new Date()); refreshData()">
            Today
          </Button>
          <div class="w-px h-5 bg-border" />
          <Button variant="ghost" size="icon" class="rounded-none h-8 w-8 sm:h-9 sm:w-9" @click="budgetStore.viewMode === 'week' ? budgetStore.prevWeek() : budgetStore.prevMonth(); refreshData()">
            <ChevronLeft class="h-4 w-4" />
          </Button>
          <div class="w-px h-5 bg-border" />
          <Button variant="ghost" size="icon" class="rounded-none h-8 w-8 sm:h-9 sm:w-9" @click="budgetStore.viewMode === 'week' ? budgetStore.nextWeek() : budgetStore.nextMonth(); refreshData()">
            <ChevronRight class="h-4 w-4" />
          </Button>
        </div>
      </div>
    </div>

    <!-- Calendar Grid - Desktop (Month View) -->
    <div v-if="budgetStore.viewMode === 'month'" class="hidden sm:block border border-border/80 rounded-xl overflow-hidden bg-card">
      <div class="grid grid-cols-7 bg-secondary/40">
        <div v-for="day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']" :key="day" class="p-2.5 text-center text-[11px] font-semibold text-muted-foreground uppercase tracking-wider">
          {{ day }}
        </div>
      </div>
      
      <div class="grid grid-cols-7">
        <div
          v-for="(day, index) in calendarDays"
          :key="index"
          :class="[
            'min-h-[88px] border-t border-r border-border p-2 last:border-r-0 [&:nth-child(7n)]:border-r-0 group',
            day && isToday(day) && 'bg-primary/[0.03]',
            !day && 'bg-secondary/20'
          ]"
        >
          <template v-if="day">
            <div class="flex items-center justify-between mb-1.5">
              <button
                :class="[
                  'inline-flex items-center justify-center text-sm font-medium hover:bg-primary/10 rounded-full transition-colors',
                  isToday(day) ? 'h-6 w-6 bg-primary text-primary-foreground text-xs' : 'h-6 w-6 text-foreground'
                ]"
                @click="openDayDetail(day)"
              >
                {{ format(day, 'd') }}
              </button>
              <button
                class="opacity-0 group-hover:opacity-100 focus:opacity-100 text-muted-foreground/60 hover:text-primary transition-all h-5 w-5 flex items-center justify-center rounded hover:bg-primary/10"
                @click="openNewEntry(day)"
              >
                <Plus class="h-3 w-3" />
              </button>
            </div>

            <!-- Trips in month view -->
            <div class="space-y-1 mb-1">
              <TripCard
                v-for="trip in calendarStore.tripsByDate[format(day, 'yyyy-MM-dd')] || []"
                :key="trip.id"
                :trip="trip"
                :compact="true"
                @click="handleTripClick"
                @delete="handleTripDelete"
              />
            </div>

            <button 
              class="w-full text-left hover:bg-secondary/50 rounded p-0.5 -mx-0.5 transition-colors"
              @click="openDayDetail(day)"
            >
              <div 
                v-if="getDayNet(day) !== 0"
                :class="[
                  'text-[11px] font-semibold tabular-nums',
                  getDayNet(day) > 0 ? 'text-emerald-600' : 'text-red-500'
                ]"
              >
                {{ getDayNet(day) > 0 ? '+' : '' }}{{ formatCurrency(getDayNet(day)) }}
              </div>
            </button>
          </template>
        </div>
      </div>
    </div>

    <!-- Budget Timeline View (Week Mode) - Habits Style -->
    <div v-if="budgetStore.viewMode === 'week'" class="hidden sm:block space-y-4">
      <!-- Day Navigation Controls -->
      <div class="flex items-center gap-3 bg-card/50 rounded-lg px-3 py-2 border border-border/50">
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-7 w-7"
          @click="goToPreviousDay"
        >
          <ChevronLeft class="h-4 w-4" />
        </Button>
        <div class="flex flex-col items-center min-w-[100px]">
          <span class="text-sm font-medium">{{ formatSelectedDay }}</span>
          <span class="text-xs text-muted-foreground" :class="isSelectedToday ? 'invisible' : ''">
            {{ isSelectedToday ? 'Today' : '' }}
          </span>
        </div>
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-7 w-7"
          @click="goToNextDay"
        >
          <ChevronRight class="h-4 w-4" />
        </Button>
        <Button 
          variant="outline" 
          size="sm" 
          class="h-7 text-xs ml-2"
          :class="isSelectedToday ? 'opacity-0 pointer-events-none' : ''"
          @click="goToToday"
        >
          Today
        </Button>
      </div>

      <!-- Timeline Inventory Header -->
      <div class="flex items-center gap-2 px-1 flex-wrap">
        <div class="w-3 h-3 rounded-full bg-primary" />
        <span class="font-semibold">{{ format(selectedDay, 'EEEE') }}</span>
        <span class="text-xs text-muted-foreground">({{ selectedDayEntries.length + selectedDayTrips.length }})</span>
        
        <!-- Summary badges -->
        <Badge v-if="selectedDayIncome > 0" variant="secondary" class="text-[10px] h-5 px-1.5 bg-emerald-500/10 text-emerald-700 border-0">
          +{{ formatCurrency(selectedDayIncome) }}
        </Badge>
        <Badge v-if="selectedDayExpense > 0" variant="secondary" class="text-[10px] h-5 px-1.5 bg-red-500/10 text-red-600 border-0">
          -{{ formatCurrency(selectedDayExpense) }}
        </Badge>
        <Badge 
          v-if="selectedDayNet !== 0" 
          variant="secondary" 
          :class="'text-[10px] h-5 px-1.5 border-0 ' + (selectedDayNet > 0 ? 'bg-emerald-500/20 text-emerald-700' : 'bg-red-500/20 text-red-600')"
        >
          Net: {{ selectedDayNet > 0 ? '+' : '' }}{{ formatCurrency(selectedDayNet) }}
        </Badge>

        <!-- Add Entry button on right -->
        <Button 
          size="sm" 
          class="ml-auto gap-1 text-xs"
          @click="openNewEntry(selectedDay)"
        >
          <Plus class="h-3 w-3" />
          Add Entry
        </Button>
      </div>

      <!-- Timeline Container -->
      <div class="flex gap-2 overflow-hidden border border-border/80 rounded-xl bg-card">
        <!-- Time markers column -->
        <div 
          class="w-12 shrink-0 relative overflow-hidden bg-secondary/20 border-r border-border/60" 
          :style="{ minHeight: `${timelineHeight}px` }"
        >
          <div 
            v-for="hour in timelineHours" 
            :key="hour"
            class="absolute left-0 right-0 text-[10px] text-muted-foreground border-t border-border/30 px-1"
            :style="{ top: `${((hour - timelineStartMins) / (timelineEndMins - timelineStartMins)) * 100}%` }"
          >
            {{ Math.floor(hour / 60).toString().padStart(2, '0') }}:00
          </div>
        </div>
        
        <!-- Entries container -->
        <div 
          class="flex-1 relative overflow-hidden p-2"
          :style="{ minHeight: `${timelineHeight}px` }"
        >
          <!-- Hour grid lines -->
          <div 
            v-for="hour in timelineHours" 
            :key="'line-' + hour"
            class="absolute left-0 right-0 border-t border-border/20"
            :style="{ top: `${((hour - timelineStartMins) / (timelineEndMins - timelineStartMins)) * 100}%` }"
          />

          <!-- Trips with purchases -->
          <Card 
            v-for="trip in selectedDayTrips" 
            :key="'trip-' + trip.id"
            class="group mb-2 hover:shadow-md transition-all duration-200 cursor-pointer overflow-hidden border-l-[3px] border-l-blue-500"
          >
            <CardContent class="p-2">
              <!-- Trip Header -->
              <div class="flex items-center gap-2 mb-1">
                <div class="h-6 w-6 rounded bg-blue-500/10 flex items-center justify-center shrink-0">
                  <Calendar class="h-3 w-3 text-blue-600" />
                </div>
                <div class="flex-1 min-w-0">
                  <h4 class="text-xs font-medium truncate">
                    {{ trip.stops?.[0]?.store_name || 'Shopping Trip' }}
                  </h4>
                  <span class="text-[9px] text-muted-foreground">
                    {{ trip.stops?.flatMap(s => s.purchases || []).length || 0 }} items
                  </span>
                </div>
                <!-- Total for trip -->
                <span class="text-sm font-semibold tabular-nums text-red-500">
                  -{{ formatCurrency(trip.stops?.flatMap(s => s.purchases || []).reduce((sum, p) => sum + parseFloat(p.total_price || '0'), 0) || 0) }}
                </span>
                <!-- Delete button -->
                <DeleteButton @click.stop="handleTripDelete(trip.id)" />
              </div>

              <!-- Purchases list - indented -->
              <div 
                v-if="trip.stops?.some(s => s.purchases && s.purchases.length > 0)"
                class="ml-8 mt-1 space-y-0.5 border-l-2 border-border/40 pl-2"
              >
                <div 
                  v-for="purchase in trip.stops?.flatMap(s => s.purchases || []) || []" 
                  :key="purchase.id"
                  class="flex items-center justify-between text-[10px] py-0.5"
                >
                  <div class="flex items-center gap-1.5 min-w-0">
                    <span class="text-muted-foreground truncate max-w-[100px]">{{ purchase.brand }}</span>
                    <span class="truncate text-foreground/80 max-w-[120px]">{{ purchase.item }}</span>
                    <span v-if="purchase.count" class="text-muted-foreground shrink-0">x{{ purchase.count }}</span>
                  </div>
                  <span class="text-red-500 font-medium tabular-nums shrink-0">
                    {{ formatCurrency(purchase.total_price) }}
                  </span>
                </div>
              </div>
            </CardContent>
          </Card>

          <!-- Budget Entries -->
          <Card 
            v-for="entry in selectedDayEntries" 
            :key="entry.id"
            :class="'mb-2 hover:shadow-md transition-all duration-200 cursor-pointer overflow-hidden border-l-[3px] ' + (entry.type === 'income' ? 'border-l-emerald-500' : 'border-l-red-500')"
            @click="openEditEntry(entry)"
          >
            <CardContent class="p-2">
              <div class="flex items-center gap-2">
                <div 
                  :class="[
                    'h-6 w-6 rounded flex items-center justify-center shrink-0',
                    entry.type === 'income' ? 'bg-emerald-500/10' : 'bg-red-500/10'
                  ]"
                >
                  <component 
                    :is="entry.type === 'income' ? TrendingUp : TrendingDown" 
                    :class="[
                      'h-3 w-3',
                      entry.type === 'income' ? 'text-emerald-600' : 'text-red-500'
                    ]" 
                  />
                </div>
                <div class="flex-1 min-w-0">
                  <h4 class="text-xs font-medium truncate">{{ entry.source?.name || 'Entry' }}</h4>
                  <span v-if="entry.notes" class="text-[9px] text-muted-foreground truncate block">{{ entry.notes }}</span>
                </div>
                <span 
                  :class="[
                    'text-sm font-semibold tabular-nums',
                    entry.type === 'income' ? 'text-emerald-600' : 'text-red-500'
                  ]"
                >
                  {{ entry.type === 'income' ? '+' : '-' }}{{ formatCurrency(entry.amount) }}
                </span>
              </div>
            </CardContent>
          </Card>

          <!-- Empty state -->
          <div v-if="selectedDayEntries.length === 0 && selectedDayTrips.length === 0" class="flex flex-col items-center justify-center h-full min-h-[200px] text-center">
            <div class="h-12 w-12 rounded-xl bg-muted/30 flex items-center justify-center mb-3">
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
          :key="index"
          :class="[
            'min-h-[52px] border-t border-r border-border p-1 last:border-r-0 [&:nth-child(7n)]:border-r-0 flex flex-col items-center transition-colors',
            day && isToday(day) && 'bg-primary/[0.03]',
            day && (getDayTotal(day, 'income') > 0 || getDayTotal(day, 'expense') > 0) && 'active:bg-secondary/60',
            !day && 'bg-secondary/20'
          ]"
          :disabled="!day"
          @click="day && openDayDetail(day)"
        >
          <template v-if="day">
            <span :class="[
              'inline-flex items-center justify-center text-xs font-medium w-6 h-6 mb-0.5',
              isToday(day) ? 'rounded-full bg-primary text-primary-foreground' : 'text-foreground'
            ]">
              {{ format(day, 'd') }}
            </span>
            <div class="flex flex-col items-center gap-0.5">
              <span 
                v-if="getDayTotal(day, 'income') > 0"
                class="w-1.5 h-1.5 rounded-full bg-emerald-500"
              />
              <span 
                v-if="getDayTotal(day, 'expense') > 0"
                class="w-1.5 h-1.5 rounded-full bg-red-500"
              />
            </div>
          </template>
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
            <DeleteButton :adaptive="false" @click.stop="handleTripDelete(trip.id)" />
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
            <DeleteButton :adaptive="false" @click.stop="handleTripDelete(trip.id)" />
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
