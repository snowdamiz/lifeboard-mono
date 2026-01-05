<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { format, subMonths, startOfMonth, endOfMonth, eachMonthOfInterval, parseISO } from 'date-fns'
import { Chart as ChartJS, CategoryScale, LinearScale, PointElement, LineElement, BarElement, ArcElement, Title, Tooltip, Legend, Filler } from 'chart.js'
import { Line, Bar, Doughnut } from 'vue-chartjs'
import { 
  BarChart3, TrendingUp, Calendar, DollarSign, Target, Flame, 
  ChevronLeft, ChevronRight, Download
} from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Select } from '@/components/ui/select'
import { useCalendarStore } from '@/stores/calendar'
import { useBudgetStore } from '@/stores/budget'
import { useGoalsStore } from '@/stores/goals'
import { useHabitsStore } from '@/stores/habits'
import { formatCurrency } from '@/lib/utils'

// Register Chart.js components
ChartJS.register(
  CategoryScale, LinearScale, PointElement, LineElement, 
  BarElement, ArcElement, Title, Tooltip, Legend, Filler
)

const calendarStore = useCalendarStore()
const budgetStore = useBudgetStore()
const goalsStore = useGoalsStore()
const habitsStore = useHabitsStore()

const loading = ref(true)
const selectedPeriod = ref(6) // months

// Get last N months
const monthsRange = computed(() => {
  const end = new Date()
  const start = subMonths(end, selectedPeriod.value - 1)
  return eachMonthOfInterval({ start: startOfMonth(start), end: endOfMonth(end) })
})

const monthLabels = computed(() => 
  monthsRange.value.map(d => format(d, 'MMM yyyy'))
)

// Real data aggregated from stores
const budgetData = computed(() => {
  const income: number[] = []
  const expenses: number[] = []
  const net: number[] = []

  for (const month of monthsRange.value) {
    const monthKey = format(month, 'yyyy-MM')
    let monthIncome = 0
    let monthExpenses = 0

    // Aggregate entries for this month
    for (const entry of budgetStore.entries) {
      const entryMonth = entry.date.substring(0, 7) // 'yyyy-MM'
      if (entryMonth === monthKey) {
        const amount = parseFloat(entry.amount) || 0
        // Use the entry's type directly
        if (entry.type === 'income') {
          monthIncome += amount
        } else {
          monthExpenses += amount
        }
      }
    }

    income.push(monthIncome)
    expenses.push(monthExpenses)
    net.push(monthIncome - monthExpenses)
  }

  return { income, expenses, net }
})

const taskData = computed(() => {
  const completed: number[] = []
  const total: number[] = []

  for (const month of monthsRange.value) {
    const monthStart = startOfMonth(month)
    const monthEnd = endOfMonth(month)
    let monthTotal = 0
    let monthCompleted = 0

    // Count tasks for this month from calendar store
    for (const [dateStr, tasks] of Object.entries(calendarStore.tasksByDate)) {
      const date = parseISO(dateStr)
      if (date >= monthStart && date <= monthEnd) {
        monthTotal += tasks.length
        monthCompleted += tasks.filter(t => t.status === 'completed').length
      }
    }

    total.push(monthTotal)
    completed.push(monthCompleted)
  }

  return { completed, total }
})

async function fetchData() {
  loading.value = true
  
  try {
    // Calculate date range for fetching entries
    const endDate = endOfMonth(new Date())
    const startDate = startOfMonth(subMonths(new Date(), selectedPeriod.value - 1))
    
    await Promise.all([
      budgetStore.fetchSources(),
      budgetStore.fetchEntries(startDate, endDate),
      calendarStore.fetchTasks(startDate, endDate),
      goalsStore.fetchGoals(),
      habitsStore.fetchHabits()
    ])
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchData()
})

watch(selectedPeriod, () => {
  fetchData()
})

// Chart configurations
const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      display: false
    }
  },
  scales: {
    y: {
      beginAtZero: true,
      grid: {
        color: 'rgba(128, 128, 128, 0.1)'
      },
      ticks: {
        color: 'rgb(128, 128, 128)'
      }
    },
    x: {
      grid: {
        display: false
      },
      ticks: {
        color: 'rgb(128, 128, 128)'
      }
    }
  }
}

const budgetChartData = computed(() => ({
  labels: monthLabels.value,
  datasets: [
    {
      label: 'Income',
      data: budgetData.value.income,
      borderColor: 'rgb(16, 185, 129)',
      backgroundColor: 'rgba(16, 185, 129, 0.1)',
      fill: true,
      tension: 0.4
    },
    {
      label: 'Expenses',
      data: budgetData.value.expenses,
      borderColor: 'rgb(239, 68, 68)',
      backgroundColor: 'rgba(239, 68, 68, 0.1)',
      fill: true,
      tension: 0.4
    }
  ]
}))

const netChartData = computed(() => ({
  labels: monthLabels.value,
  datasets: [
    {
      label: 'Net Savings',
      data: budgetData.value.net,
      backgroundColor: budgetData.value.net.map(n => n >= 0 ? 'rgba(16, 185, 129, 0.8)' : 'rgba(239, 68, 68, 0.8)'),
      borderRadius: 6
    }
  ]
}))

const taskChartData = computed(() => ({
  labels: monthLabels.value,
  datasets: [
    {
      label: 'Completed',
      data: taskData.value.completed,
      backgroundColor: 'rgba(59, 130, 246, 0.8)',
      borderRadius: 6
    },
    {
      label: 'Total',
      data: taskData.value.total,
      backgroundColor: 'rgba(59, 130, 246, 0.2)',
      borderRadius: 6
    }
  ]
}))

const goalStatusData = computed(() => {
  const active = goalsStore.activeGoals.length
  const completed = goalsStore.completedGoals.length
  const abandoned = goalsStore.goals.filter(g => g.status === 'abandoned').length
  
  return {
    labels: ['Active', 'Completed', 'Abandoned'],
    datasets: [{
      data: [active, completed, abandoned],
      backgroundColor: [
        'rgba(59, 130, 246, 0.8)',
        'rgba(16, 185, 129, 0.8)',
        'rgba(156, 163, 175, 0.8)'
      ],
      borderWidth: 0
    }]
  }
})

const doughnutOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom' as const,
      labels: {
        color: 'rgb(128, 128, 128)',
        padding: 16
      }
    }
  },
  cutout: '65%'
}

// Summary stats
const totalIncome = computed(() => budgetData.value.income.reduce((a, b) => a + b, 0))
const totalExpenses = computed(() => budgetData.value.expenses.reduce((a, b) => a + b, 0))
const totalNet = computed(() => totalIncome.value - totalExpenses.value)
const avgCompletionRate = computed(() => {
  if (taskData.value.total.length === 0) return 0
  const totalCompleted = taskData.value.completed.reduce((a, b) => a + b, 0)
  const total = taskData.value.total.reduce((a, b) => a + b, 0)
  return total > 0 ? Math.round((totalCompleted / total) * 100) : 0
})
</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <BarChart3 class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Reports</h1>
          <p class="text-sm text-muted-foreground">Analytics and trends across all modules</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <Select 
          v-model="selectedPeriod"
          :options="[
            { value: 3, label: 'Last 3 months' },
            { value: 6, label: 'Last 6 months' },
            { value: 12, label: 'Last 12 months' }
          ]"
          size="sm"
          class="w-40"
        />
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-20">
      <div class="h-6 w-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
    </div>

    <template v-else>
      <!-- Summary Cards -->
      <div class="grid gap-3 sm:gap-4 grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardContent class="p-4">
            <div class="flex items-center gap-3">
              <div class="h-9 w-9 rounded-lg bg-emerald-500/10 flex items-center justify-center">
                <TrendingUp class="h-5 w-5 text-emerald-600" />
              </div>
              <div>
                <p class="text-xs text-muted-foreground">Total Income</p>
                <p class="text-lg font-bold text-emerald-600">{{ formatCurrency(totalIncome) }}</p>
              </div>
            </div>
          </CardContent>
        </Card>
        
        <Card>
          <CardContent class="p-4">
            <div class="flex items-center gap-3">
              <div class="h-9 w-9 rounded-lg bg-red-500/10 flex items-center justify-center">
                <DollarSign class="h-5 w-5 text-red-600" />
              </div>
              <div>
                <p class="text-xs text-muted-foreground">Total Expenses</p>
                <p class="text-lg font-bold text-red-500">{{ formatCurrency(totalExpenses) }}</p>
              </div>
            </div>
          </CardContent>
        </Card>
        
        <Card>
          <CardContent class="p-4">
            <div class="flex items-center gap-3">
              <div class="h-9 w-9 rounded-lg bg-blue-500/10 flex items-center justify-center">
                <Calendar class="h-5 w-5 text-blue-600" />
              </div>
              <div>
                <p class="text-xs text-muted-foreground">Task Completion</p>
                <p class="text-lg font-bold">{{ avgCompletionRate }}%</p>
              </div>
            </div>
          </CardContent>
        </Card>
        
        <Card>
          <CardContent class="p-4">
            <div class="flex items-center gap-3">
              <div class="h-9 w-9 rounded-lg bg-violet-500/10 flex items-center justify-center">
                <Target class="h-5 w-5 text-violet-600" />
              </div>
              <div>
                <p class="text-xs text-muted-foreground">Net Savings</p>
                <p :class="['text-lg font-bold', totalNet >= 0 ? 'text-emerald-600' : 'text-red-500']">
                  {{ formatCurrency(totalNet) }}
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <!-- Charts Grid -->
      <div class="grid gap-4 lg:grid-cols-2">
        <!-- Budget Trend -->
        <Card>
          <CardHeader class="pb-2">
            <CardTitle class="text-base flex items-center gap-2">
              <DollarSign class="h-4 w-4 text-emerald-600" />
              Income vs Expenses
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div class="h-64">
              <Line :data="budgetChartData" :options="chartOptions" />
            </div>
          </CardContent>
        </Card>

        <!-- Net Savings -->
        <Card>
          <CardHeader class="pb-2">
            <CardTitle class="text-base flex items-center gap-2">
              <TrendingUp class="h-4 w-4 text-blue-600" />
              Monthly Net Savings
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div class="h-64">
              <Bar :data="netChartData" :options="chartOptions" />
            </div>
          </CardContent>
        </Card>

        <!-- Task Completion -->
        <Card>
          <CardHeader class="pb-2">
            <CardTitle class="text-base flex items-center gap-2">
              <Calendar class="h-4 w-4 text-blue-600" />
              Task Completion Rate
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div class="h-64">
              <Bar :data="taskChartData" :options="chartOptions" />
            </div>
          </CardContent>
        </Card>

        <!-- Goal Status -->
        <Card>
          <CardHeader class="pb-2">
            <CardTitle class="text-base flex items-center gap-2">
              <Target class="h-4 w-4 text-violet-600" />
              Goals Overview
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div class="h-64 flex items-center justify-center">
              <div class="w-48 h-48">
                <Doughnut :data="goalStatusData" :options="doughnutOptions" />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      <!-- Habits Summary -->
      <Card>
        <CardHeader class="pb-2">
          <CardTitle class="text-base flex items-center gap-2">
            <Flame class="h-4 w-4 text-orange-500" />
            Habits Summary
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div v-if="habitsStore.habits.length === 0" class="text-center py-8 text-muted-foreground">
            No habits created yet
          </div>
          <div v-else class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            <div 
              v-for="habit in habitsStore.habits.slice(0, 6)" 
              :key="habit.id"
              class="flex items-center gap-3 p-3 rounded-lg bg-secondary/30"
            >
              <div 
                class="h-10 w-10 rounded-lg flex items-center justify-center"
                :style="{ backgroundColor: habit.color + '20' }"
              >
                <Flame class="h-5 w-5" :style="{ color: habit.color }" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="font-medium text-sm truncate">{{ habit.name }}</p>
                <div class="flex items-center gap-2 text-xs text-muted-foreground">
                  <span>{{ habit.streak_count }} day streak</span>
                  <span>•</span>
                  <span>Best: {{ habit.longest_streak }}</span>
                </div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </template>
  </div>
</template>

