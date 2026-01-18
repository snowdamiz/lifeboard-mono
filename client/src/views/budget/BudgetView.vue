<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { format, startOfMonth, endOfMonth, eachDayOfInterval, isSameMonth, isToday, getDay, startOfWeek, endOfWeek } from 'date-fns'
import { ChevronLeft, ChevronRight, Plus, TrendingUp, TrendingDown, Wallet, Percent, Settings, Calendar, CalendarDays, Filter, X } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { useBudgetStore } from '@/stores/budget'
import { formatCurrency } from '@/lib/utils'
import BudgetEntryForm from '@/components/budget/BudgetEntryForm.vue'
import BudgetDayDetail from '@/components/budget/BudgetDayDetail.vue'
import TagManager from '@/components/shared/TagManager.vue'
import type { BudgetEntry } from '@/types'

const budgetStore = useBudgetStore()
const showEntryForm = ref(false)
const showDayDetail = ref(false)
const selectedDate = ref<Date | null>(null)
const editingEntry = ref<BudgetEntry | null>(null)


const calendarDays = computed(() => {
  const start = startOfMonth(budgetStore.currentMonth)
  const end = endOfMonth(budgetStore.currentMonth)
  const days = eachDayOfInterval({ start, end })
  
  // Add padding for first week
  const startDay = getDay(start)
  const padding = Array(startDay === 0 ? 6 : startDay - 1).fill(null)
  
  return [...padding, ...days]
})

// Weekly view days
const weekDays = computed(() => {
  const start = startOfWeek(budgetStore.currentWeek, { weekStartsOn: 1 })
  const end = endOfWeek(budgetStore.currentWeek, { weekStartsOn: 1 })
  return eachDayOfInterval({ start, end })
})

const isFilterOpen = ref(false)
const filterCheckedTagIds = ref<Set<string>>(new Set())

// Sync filter tags from store to local state when store changes
watch(() => budgetStore.filterTags, (newTags) => {
  filterCheckedTagIds.value = new Set(newTags)
}, { immediate: true })

const activeFilterCount = computed(() => budgetStore.filterTags.length)

const toggleFilterTag = async (tagId: string) => {
  const index = budgetStore.filterTags.indexOf(tagId)
  if (index === -1) {
    budgetStore.filterTags.push(tagId)
  } else {
    budgetStore.filterTags.splice(index, 1)
  }
  await Promise.all([
    budgetStore.fetchCurrentViewEntries(),
    budgetStore.fetchSummary()
  ])
}

const applyFilters = async () => {
  budgetStore.filterTags = Array.from(filterCheckedTagIds.value)
  await Promise.all([
    budgetStore.fetchCurrentViewEntries(),
    budgetStore.fetchSummary()
  ])
  isFilterOpen.value = false
}

const clearFilters = async () => {
  budgetStore.filterTags = []
  await Promise.all([
    budgetStore.fetchCurrentViewEntries(),
    budgetStore.fetchSummary()
  ])
  isFilterOpen.value = false
}

onMounted(async () => {
  // Reset filters
  budgetStore.filterTags = []
  await Promise.all([
    budgetStore.fetchSources(),
    budgetStore.fetchMonthEntries(),
    budgetStore.fetchSummary()
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
  await Promise.all([
    budgetStore.fetchCurrentViewEntries(), // Use current view instead of hardcoded month
    budgetStore.fetchSummary()
  ])
}
</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in pb-20 sm:pb-0">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-start sm:items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Wallet class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Budget</h1>
          <p class="text-muted-foreground text-sm mt-0.5">Track income and expenses</p>
        </div>
      </div>

      <div class="flex items-center gap-2 sm:gap-3 w-full sm:w-auto">
        <div class="relative flex-1 sm:flex-none">
          <Button 
            variant="outline" 
            size="sm" 
            class="h-9 w-full sm:w-auto relative" 
            :class="{ 'border-primary text-primary': activeFilterCount > 0 }"
            @click="isFilterOpen = !isFilterOpen"
          >
            <Filter class="h-4 w-4 sm:mr-2" />
            <span class="hidden sm:inline">Filter</span>
            <span class="sm:hidden">Filter</span>
            <Badge 
              v-if="activeFilterCount > 0" 
              variant="secondary" 
              class="ml-2 h-5 min-w-[20px] px-1 bg-primary text-primary-foreground hover:bg-primary/90"
            >
              {{ activeFilterCount }}
            </Badge>
          </Button>

          <!-- Filter Dropdown -->
          <div 
            v-if="isFilterOpen" 
            class="absolute right-0 top-full mt-2 w-80 bg-popover text-popover-foreground border rounded-lg shadow-lg z-50 overflow-hidden"
          >
            <div class="p-3 border-b flex items-center justify-between">
              <div>
                <h4 class="font-medium leading-none">Filter Entries</h4>
                <p class="text-xs text-muted-foreground mt-1.5">Select tags to filter by</p>
              </div>
              <button class="text-xs text-primary hover:underline" @click="clearFilters" v-if="activeFilterCount > 0">
                Clear all
              </button>
            </div>
            <div class="p-2">
              <TagManager
                v-model:checkedTagIds="filterCheckedTagIds"
                mode="select"
                embedded
                :rows="3"
              />
            </div>
            <div class="p-3 border-t bg-muted/20 flex justify-between gap-2">
              <Button variant="ghost" size="sm" @click="clearFilters" :disabled="activeFilterCount === 0">
                Clear
              </Button>
              <Button size="sm" @click="applyFilters">
                Apply
              </Button>
            </div>
          </div>
          <!-- Backdrop -->
          <div v-if="isFilterOpen" class="fixed inset-0 z-40 bg-transparent" @click="isFilterOpen = false" />
        </div>

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
      </div>
    </div>
    
    <!-- Active Filters Display -->
    <div v-if="activeFilterCount > 0" class="flex flex-wrap gap-2 items-center">
      <span class="text-xs text-muted-foreground">Active filters:</span>
      <Badge 
        v-for="tagId in budgetStore.filterTags" 
        :key="tagId"
        variant="secondary"
        class="gap-1 pl-2 pr-1 py-0.5"
      >
        <span class="truncate max-w-[100px]">Tag selected</span>
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-3 w-3 sm:h-4 sm:w-4 ml-1 rounded-full -mr-0.5 hover:bg-transparent hover:text-destructive"
          @click.stop="toggleFilterTag(tagId); applyFilters()"
        >
          <X class="h-2 w-2 sm:h-3 sm:w-3" />
        </Button>
      </Badge>
      <Button variant="link" size="sm" class="h-auto p-0 text-xs text-muted-foreground" @click="clearFilters">
        Clear all
      </Button>
    </div>

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
            'min-h-[88px] border-t border-r border-border/60 p-2 last:border-r-0 [&:nth-child(7n)]:border-r-0 group',
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

    <!-- Calendar Grid - Desktop (Week View) -->
    <div v-if="budgetStore.viewMode === 'week'" class="hidden sm:block border border-border/80 rounded-xl overflow-hidden bg-card">
      <div class="grid grid-cols-7 bg-secondary/40">
        <div v-for="(day, index) in weekDays" :key="index" class="p-2.5 text-center text-[11px] font-semibold text-muted-foreground uppercase tracking-wider">
          <div>{{ format(day, 'EEE') }}</div>
          <div :class="['text-lg font-semibold mt-0.5', isToday(day) ? 'text-primary' : 'text-foreground']">
            {{ format(day, 'd') }}
          </div>
        </div>
      </div>
      
      <div class="grid grid-cols-7">
        <div
          v-for="(day, index) in weekDays"
          :key="index"
          :class="[
            'min-h-[180px] border-t border-r border-border/60 p-2 last:border-r-0 [&:nth-child(7n)]:border-r-0 group',
            isToday(day) && 'bg-primary/[0.03]'
          ]"
        >
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-1.5">
              <span v-if="getDayTotal(day, 'income') > 0" class="text-xs text-emerald-600 font-semibold tabular-nums">
                +{{ formatCurrency(getDayTotal(day, 'income')) }}
              </span>
              <span v-if="getDayTotal(day, 'expense') > 0" class="text-xs text-red-500 font-semibold tabular-nums">
                -{{ formatCurrency(getDayTotal(day, 'expense')) }}
              </span>
            </div>
            <button
              class="opacity-0 group-hover:opacity-100 text-muted-foreground/60 hover:text-primary transition-all h-5 w-5 flex items-center justify-center rounded hover:bg-primary/10"
              @click="openNewEntry(day)"
            >
              <Plus class="h-3 w-3" />
            </button>
          </div>

          <!-- Entry list for week view -->
          <div class="space-y-1.5">
            <div
              v-for="entry in getDayEntries(day)"
              :key="entry.id"
              :class="[
                'text-[11px] px-1.5 py-1 rounded-md cursor-pointer hover:opacity-80 transition-opacity',
                entry.type === 'income' ? 'bg-emerald-500/10 text-emerald-700' : 'bg-red-500/10 text-red-600'
              ]"
              @click="openDayDetail(day)"
            >
              <div class="font-medium truncate">{{ entry.source?.name || 'Entry' }}</div>
              <div class="tabular-nums">{{ formatCurrency(entry.amount) }}</div>
            </div>
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
            'min-h-[52px] border-t border-r border-border/60 p-1 last:border-r-0 [&:nth-child(7n)]:border-r-0 flex flex-col items-center transition-colors',
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

    <!-- Calendar Grid - Mobile (Week View) -->
    <div v-if="budgetStore.viewMode === 'week'" class="sm:hidden border border-border/80 rounded-xl overflow-hidden bg-card">
      <div class="grid grid-cols-7 bg-secondary/40">
        <div 
          v-for="(day, index) in weekDays" 
          :key="index" 
          class="p-1.5 text-center"
        >
          <div class="text-[9px] font-semibold text-muted-foreground">{{ format(day, 'EEE') }}</div>
          <div :class="['text-sm font-semibold mt-0.5', isToday(day) ? 'text-primary' : 'text-foreground']">
            {{ format(day, 'd') }}
          </div>
        </div>
      </div>
      
      <div class="grid grid-cols-7">
        <button
          v-for="(day, index) in weekDays"
          :key="index"
          :class="[
            'min-h-[70px] border-t border-r border-border/60 p-1 last:border-r-0 [&:nth-child(7n)]:border-r-0 flex flex-col items-center transition-colors active:bg-secondary/60',
            isToday(day) && 'bg-primary/[0.03]'
          ]"
          @click="openDayDetail(day)"
        >
          <div class="flex flex-col items-center gap-0.5">
            <span 
              v-if="getDayTotal(day, 'income') > 0"
              class="text-[9px] text-emerald-600 font-semibold tabular-nums"
            >
              +{{ getDayTotal(day, 'income').toFixed(0) }}
            </span>
            <span 
              v-if="getDayTotal(day, 'expense') > 0"
              class="text-[9px] text-red-500 font-semibold tabular-nums"
            >
              -{{ getDayTotal(day, 'expense').toFixed(0) }}
            </span>
          </div>
        </button>
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
  </div>
</template>
