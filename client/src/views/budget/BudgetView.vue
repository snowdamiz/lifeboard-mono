<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { format, startOfMonth, endOfMonth, eachDayOfInterval, isSameMonth, isToday, getDay } from 'date-fns'
import { ChevronLeft, ChevronRight, Plus, TrendingUp, TrendingDown, Wallet, Percent, Settings } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { useBudgetStore } from '@/stores/budget'
import { formatCurrency } from '@/lib/utils'
import BudgetEntryForm from '@/components/budget/BudgetEntryForm.vue'
import BudgetDayDetail from '@/components/budget/BudgetDayDetail.vue'

const budgetStore = useBudgetStore()
const showEntryForm = ref(false)
const showDayDetail = ref(false)
const selectedDate = ref<Date | null>(null)

const calendarDays = computed(() => {
  const start = startOfMonth(budgetStore.currentMonth)
  const end = endOfMonth(budgetStore.currentMonth)
  const days = eachDayOfInterval({ start, end })
  
  // Add padding for first week
  const startDay = getDay(start)
  const padding = Array(startDay === 0 ? 6 : startDay - 1).fill(null)
  
  return [...padding, ...days]
})

onMounted(async () => {
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
  showDayDetail.value = false
  showEntryForm.value = true
}

const refreshData = async () => {
  await Promise.all([
    budgetStore.fetchMonthEntries(),
    budgetStore.fetchSummary()
  ])
}
</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Wallet class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Budget</h1>
          <p class="text-muted-foreground text-sm mt-0.5">Track income and expenses</p>
        </div>
      </div>

      <div class="flex items-center gap-2 sm:gap-3">
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
    <div class="flex items-center justify-between">
      <h2 class="text-base sm:text-lg font-medium">
        {{ format(budgetStore.currentMonth, 'MMMM yyyy') }}
      </h2>
      <div class="flex items-center rounded-lg border border-border bg-card overflow-hidden">
        <Button variant="ghost" size="icon" class="rounded-none h-8 w-8 sm:h-9 sm:w-9" @click="budgetStore.prevMonth(); refreshData()">
          <ChevronLeft class="h-4 w-4" />
        </Button>
        <div class="w-px h-5 bg-border" />
        <Button variant="ghost" size="sm" class="rounded-none px-2 sm:px-4 h-8 sm:h-9 text-xs sm:text-[13px]" @click="budgetStore.setCurrentMonth(new Date()); refreshData()">
          Today
        </Button>
        <div class="w-px h-5 bg-border" />
        <Button variant="ghost" size="icon" class="rounded-none h-8 w-8 sm:h-9 sm:w-9" @click="budgetStore.nextMonth(); refreshData()">
          <ChevronRight class="h-4 w-4" />
        </Button>
      </div>
    </div>

    <!-- Calendar Grid - Desktop -->
    <div class="hidden sm:block border border-border/80 rounded-xl overflow-hidden bg-card">
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
              class="w-full text-left space-y-0.5 hover:bg-secondary/50 rounded p-0.5 -mx-0.5 transition-colors"
              @click="openDayDetail(day)"
            >
              <div 
                v-if="getDayTotal(day, 'income') > 0"
                class="text-[11px] text-emerald-600 font-semibold tabular-nums"
              >
                +{{ formatCurrency(getDayTotal(day, 'income')) }}
              </div>
              <div 
                v-if="getDayTotal(day, 'expense') > 0"
                class="text-[11px] text-red-500 font-semibold tabular-nums"
              >
                -{{ formatCurrency(getDayTotal(day, 'expense')) }}
              </div>
            </button>
          </template>
        </div>
      </div>
    </div>

    <!-- Calendar Grid - Mobile (Compact View) -->
    <div class="sm:hidden border border-border/80 rounded-xl overflow-hidden bg-card">
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

    <!-- Mobile: Recent Entries List -->
    <div class="sm:hidden space-y-2">
      <h3 class="text-sm font-medium text-muted-foreground">Recent entries this month</h3>
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
      @refresh="refreshData()"
    />

    <BudgetEntryForm
      v-if="showEntryForm"
      :initial-date="selectedDate"
      @close="showEntryForm = false"
      @saved="showEntryForm = false; refreshData()"
    />
  </div>
</template>
