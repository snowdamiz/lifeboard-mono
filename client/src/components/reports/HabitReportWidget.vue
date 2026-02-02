<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { format, subDays } from 'date-fns'
import { Line, Bar, Doughnut } from 'vue-chartjs'
import { X, Settings, ChevronDown, Flame, TrendingUp, PieChart, BarChart3, Activity, CalendarDays } from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Select } from '@/components/ui/select'
import { DateChooser } from '@/components/ui/date-chooser'
import { useHabitsStore } from '@/stores/habits'
import type { HabitAnalytics, HabitInventory, Tag } from '@/types'

interface Props {
  id: string
  inventories: HabitInventory[]
  tags: Tag[]
}

const props = defineProps<Props>()
const emit = defineEmits<{
  remove: [id: string]
}>()

const habitsStore = useHabitsStore()

// Widget configuration
const reportType = ref<'completion_rate' | 'habits_per_day' | 'skip_reasons' | 'streak_chart' | 'weekly_trends'>('completion_rate')
const dateRangeMode = ref<'last_7' | 'last_30' | 'last_90' | 'rolling_7' | 'rolling_14' | 'rolling_30' | 'from_date' | 'custom'>('last_30')
const inventoryId = ref<string>('')
const statusFilter = ref<'all' | 'completed' | 'skipped'>('all')
const showSettings = ref(false)
const loading = ref(false)
const selectedTagIds = ref<string[]>([])

// Custom date range
const customStartDate = ref(format(subDays(new Date(), 30), 'yyyy-MM-dd'))
const customEndDate = ref(format(new Date(), 'yyyy-MM-dd'))

// Analytics data
const analyticsData = ref<HabitAnalytics | null>(null)

// Computed date range
const dateRange = computed(() => {
  const today = new Date()
  let startDate: Date
  let endDate = today

  switch (dateRangeMode.value) {
    case 'last_7':
      startDate = subDays(today, 7)
      break
    case 'last_30':
      startDate = subDays(today, 30)
      break
    case 'last_90':
      startDate = subDays(today, 90)
      break
    case 'rolling_7':
      // T-7 to T-0 (updates daily)
      startDate = subDays(today, 7)
      break
    case 'rolling_14':
      // T-14 to T-0
      startDate = subDays(today, 14)
      break
    case 'rolling_30':
      // T-30 to T-0
      startDate = subDays(today, 30)
      break
    case 'from_date':
      // From specific start date to today
      startDate = new Date(customStartDate.value)
      endDate = today
      break
    case 'custom':
      startDate = new Date(customStartDate.value)
      endDate = new Date(customEndDate.value)
      break
    default:
      startDate = subDays(today, 30)
  }

  return {
    start: format(startDate, 'yyyy-MM-dd'),
    end: format(endDate, 'yyyy-MM-dd')
  }
})

// Report type options
const reportTypeOptions = [
  { value: 'completion_rate', label: 'Completion Rate' },
  { value: 'habits_per_day', label: 'Habits Per Day' },
  { value: 'skip_reasons', label: 'Skip Reasons' },
  { value: 'streak_chart', label: 'Streak Progress' },
  { value: 'weekly_trends', label: 'Weekly Trends' }
]

// Date range options
const dateRangeOptions = [
  { value: 'last_7', label: 'Last 7 days' },
  { value: 'last_30', label: 'Last 30 days' },
  { value: 'last_90', label: 'Last 90 days' },
  { value: 'rolling_7', label: 'Rolling 7 days (T-7 → now)' },
  { value: 'rolling_14', label: 'Rolling 14 days (T-14 → now)' },
  { value: 'rolling_30', label: 'Rolling 30 days (T-30 → now)' },
  { value: 'from_date', label: 'From specific date → now' },
  { value: 'custom', label: 'Custom date range' }
]

// Inventory options with "All" option
const inventoryOptions = computed(() => [
  { value: '', label: 'All Inventories' },
  ...props.inventories.map(inv => ({ value: inv.id, label: inv.name }))
])

// Status filter options
const statusFilterOptions = [
  { value: 'all', label: 'All Entries' },
  { value: 'completed', label: 'Completed Only' },
  { value: 'skipped', label: 'Skipped Only' }
]

// Error state
const hasError = ref(false)

// Fetch analytics data
async function fetchAnalytics() {
  loading.value = true
  hasError.value = false
  try {
    const params: {
      start_date: string
      end_date: string
      inventory_id?: string
      tag_ids?: string[]
      status_filter?: string
    } = {
      start_date: dateRange.value.start,
      end_date: dateRange.value.end
    }
    
    if (inventoryId.value) {
      params.inventory_id = inventoryId.value
    }

    if (statusFilter.value !== 'all') {
      params.status_filter = statusFilter.value
    }

    if (selectedTagIds.value.length > 0) {
      params.tag_ids = selectedTagIds.value
    }

    const data = await habitsStore.fetchHabitAnalytics(params)
    if (data) {
      analyticsData.value = data
    } else {
      // Use empty data if null returned
      analyticsData.value = {
        total_entries: 0,
        completed_count: 0,
        skipped_count: 0,
        completion_rate: 0,
        completions_by_day: [],
        skip_reasons: [],
        habits_per_day: []
      }
    }
  } catch (error) {
    console.error('Failed to fetch habit analytics:', error)
    hasError.value = true
    // Set empty data on error so charts don't break
    analyticsData.value = {
      total_entries: 0,
      completed_count: 0,
      skipped_count: 0,
      completion_rate: 0,
      completions_by_day: [],
      skip_reasons: [],
      habits_per_day: []
    }
  } finally {
    loading.value = false
  }
}

// Watch for changes and refetch
watch([dateRange, inventoryId, selectedTagIds, statusFilter], () => {
  fetchAnalytics()
}, { immediate: true })

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
        color: 'rgb(128, 128, 128)',
        maxRotation: 45,
        minRotation: 0
      }
    }
  }
}

const doughnutOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: {
      position: 'bottom' as const,
      labels: {
        color: 'rgb(128, 128, 128)',
        padding: 12
      }
    }
  },
  cutout: '60%'
}

// Chart data computeds
const completionRateChartData = computed(() => {
  if (!analyticsData.value?.completions_by_day) {
    return { labels: [], datasets: [] }
  }

  const sorted = [...analyticsData.value.completions_by_day].sort(
    (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()
  )

  return {
    labels: sorted.map(d => format(new Date(d.date), 'MMM d')),
    datasets: [{
      label: 'Completion Rate %',
      data: sorted.map(d => d.completion_rate),
      borderColor: 'rgb(16, 185, 129)',
      backgroundColor: 'rgba(16, 185, 129, 0.1)',
      fill: true,
      tension: 0.4
    }]
  }
})

const habitsPerDayChartData = computed(() => {
  if (!analyticsData.value?.habits_per_day) {
    return { labels: [], datasets: [] }
  }

  const sorted = [...analyticsData.value.habits_per_day].sort(
    (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime()
  )

  return {
    labels: sorted.map(d => format(new Date(d.date), 'MMM d')),
    datasets: [{
      label: 'Habits Completed',
      data: sorted.map(d => d.count),
      backgroundColor: 'rgba(59, 130, 246, 0.8)',
      borderRadius: 4
    }]
  }
})

const skipReasonsChartData = computed(() => {
  if (!analyticsData.value?.skip_reasons || analyticsData.value.skip_reasons.length === 0) {
    return {
      labels: ['No skips'],
      datasets: [{
        data: [1],
        backgroundColor: ['rgba(156, 163, 175, 0.5)'],
        borderWidth: 0
      }]
    }
  }

  const colors = [
    'rgba(239, 68, 68, 0.8)',
    'rgba(249, 115, 22, 0.8)',
    'rgba(234, 179, 8, 0.8)',
    'rgba(34, 197, 94, 0.8)',
    'rgba(59, 130, 246, 0.8)',
    'rgba(147, 51, 234, 0.8)'
  ]

  return {
    labels: analyticsData.value.skip_reasons.map(s => s.reason || 'Unspecified'),
    datasets: [{
      data: analyticsData.value.skip_reasons.map(s => s.count),
      backgroundColor: analyticsData.value.skip_reasons.map((_, i) => colors[i % colors.length]),
      borderWidth: 0
    }]
  }
})

// Streak chart data (current vs longest streak per habit)
const streakChartData = computed(() => {
  const habits = habitsStore.habits
  if (!habits.length) {
    return { labels: [], datasets: [] }
  }

  // Filter by inventory if selected
  const filteredHabits = inventoryId.value 
    ? habits.filter(h => h.inventory_id === inventoryId.value)
    : habits

  const sorted = [...filteredHabits].sort((a, b) => b.streak_count - a.streak_count).slice(0, 10)

  return {
    labels: sorted.map(h => h.name.length > 15 ? h.name.slice(0, 15) + '...' : h.name),
    datasets: [
      {
        label: 'Current Streak',
        data: sorted.map(h => h.streak_count),
        backgroundColor: 'rgba(16, 185, 129, 0.8)',
        borderRadius: 4
      },
      {
        label: 'Longest Streak',
        data: sorted.map(h => h.longest_streak),
        backgroundColor: 'rgba(59, 130, 246, 0.4)',
        borderRadius: 4
      }
    ]
  }
})

// Weekly trends chart data (completion rates by day of week)
const weeklyTrendsChartData = computed(() => {
  if (!analyticsData.value?.completions_by_day) {
    return { labels: [], datasets: [] }
  }

  // Group by day of week
  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  const byDayOfWeek: { [key: number]: { completed: number; total: number } } = {}

  for (let i = 0; i < 7; i++) {
    byDayOfWeek[i] = { completed: 0, total: 0 }
  }

  for (const day of analyticsData.value.completions_by_day) {
    const dayOfWeek = new Date(day.date).getDay()
    byDayOfWeek[dayOfWeek].completed += day.completed
    byDayOfWeek[dayOfWeek].total += day.total
  }

  const rates = dayNames.map((_, i) => {
    const d = byDayOfWeek[i]
    return d.total > 0 ? Math.round((d.completed / d.total) * 100) : 0
  })

  return {
    labels: dayNames,
    datasets: [{
      label: 'Completion Rate %',
      data: rates,
      backgroundColor: rates.map(r => r >= 80 ? 'rgba(16, 185, 129, 0.8)' : r >= 50 ? 'rgba(234, 179, 8, 0.8)' : 'rgba(239, 68, 68, 0.8)'),
      borderRadius: 4
    }]
  }
})

// Report title based on type
const reportTitle = computed(() => {
  switch (reportType.value) {
    case 'completion_rate': return 'Completion Rate Over Time'
    case 'habits_per_day': return 'Habits Completed Per Day'
    case 'skip_reasons': return 'Skip Reasons Distribution'
    case 'streak_chart': return 'Streak Progress'
    case 'weekly_trends': return 'Weekly Breakdown'
    default: return 'Habit Report'
  }
})

// Report icon based on type
const ReportIcon = computed(() => {
  switch (reportType.value) {
    case 'completion_rate': return TrendingUp
    case 'habits_per_day': return BarChart3
    case 'skip_reasons': return PieChart
    case 'streak_chart': return Activity
    case 'weekly_trends': return CalendarDays
    default: return Flame
  }
})

// Stat summaries
const summaryStats = computed(() => {
  if (!analyticsData.value) return null
  
  return {
    totalEntries: analyticsData.value.total_entries,
    completionRate: analyticsData.value.completion_rate,
    completed: analyticsData.value.completed_count,
    skipped: analyticsData.value.skipped_count
  }
})
</script>

<template>
  <Card class="relative group">
    <CardHeader class="pb-2">
      <div class="flex items-center justify-between">
        <CardTitle class="text-base flex items-center gap-2">
          <component :is="ReportIcon" class="h-4 w-4 text-orange-500" />
          {{ reportTitle }}
        </CardTitle>
        <div class="flex items-center gap-1">
          <button
            type="button"
            class="h-8 w-8 p-0 flex items-center justify-center rounded-md text-gray-400 hover:text-white hover:bg-gray-700 border border-gray-600"
            @click="showSettings = !showSettings"
            title="Report Settings"
          >
            <Settings class="h-4 w-4" />
          </button>
          <button
            type="button"
            class="h-8 w-8 p-0 flex items-center justify-center rounded-md text-gray-400 hover:text-red-400 hover:bg-red-500/20 border border-gray-600"
            @click="emit('remove', id)"
            title="Remove Report"
          >
            <X class="h-4 w-4" />
          </button>
        </div>
      </div>

      <!-- Settings panel -->
      <div v-if="showSettings" class="mt-3 space-y-3 p-3 rounded-lg bg-secondary/30">
        <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div>
            <label class="text-xs text-muted-foreground mb-1 block">Report Type</label>
            <Select
              v-model="reportType"
              :options="reportTypeOptions"
              size="sm"
            />
          </div>
          <div>
            <label class="text-xs text-muted-foreground mb-1 block">Date Range</label>
            <Select
              v-model="dateRangeMode"
              :options="dateRangeOptions"
              size="sm"
            />
          </div>
          <div>
            <label class="text-xs text-muted-foreground mb-1 block">Inventory</label>
            <Select
              v-model="inventoryId"
              :options="inventoryOptions"
              size="sm"
            />
          </div>
          <div>
            <label class="text-xs text-muted-foreground mb-1 block">Status</label>
            <Select
              v-model="statusFilter"
              :options="statusFilterOptions"
              size="sm"
            />
          </div>
          <div>
            <label class="text-xs text-muted-foreground mb-1 block">Tags</label>
            <div class="relative">
              <select
                v-model="selectedTagIds"
                multiple
                class="w-full h-8 px-2 text-sm rounded-md border border-input bg-background focus:outline-none focus:ring-1 focus:ring-ring"
                :class="selectedTagIds.length > 0 ? 'text-foreground' : 'text-muted-foreground'"
              >
                <option v-for="tag in tags" :key="tag.id" :value="tag.id">
                  {{ tag.name }}
                </option>
              </select>
              <span v-if="selectedTagIds.length === 0 && tags.length === 0" class="absolute left-2 top-1/2 -translate-y-1/2 text-xs text-muted-foreground pointer-events-none">
                No tags
              </span>
            </div>
          </div>
        </div>

        <!-- Custom date inputs -->
        <div v-if="dateRangeMode === 'from_date'" class="grid gap-3">
          <div>
            <label class="text-xs text-muted-foreground mb-1 block">Start Date (report from this day → today)</label>
            <DateChooser v-model="customStartDate" />
          </div>
        </div>
        <div v-if="dateRangeMode === 'custom'" class="grid gap-3 sm:grid-cols-2">
          <div>
            <label class="text-xs text-muted-foreground mb-1 block">Start Date</label>
            <DateChooser v-model="customStartDate" />
          </div>
          <div>
            <label class="text-xs text-muted-foreground mb-1 block">End Date</label>
            <DateChooser v-model="customEndDate" />
          </div>
        </div>
      </div>

      <!-- Quick info badges -->
      <div v-if="summaryStats && !showSettings" class="flex items-center gap-2 mt-2 flex-wrap">
        <span class="text-xs px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-600">
          {{ summaryStats.completionRate }}% avg
        </span>
        <span class="text-xs px-2 py-0.5 rounded-full bg-blue-500/10 text-blue-600">
          {{ summaryStats.completed }} done
        </span>
        <span v-if="summaryStats.skipped > 0" class="text-xs px-2 py-0.5 rounded-full bg-orange-500/10 text-orange-600">
          {{ summaryStats.skipped }} skipped
        </span>
        <span v-if="inventoryId" class="text-xs px-2 py-0.5 rounded-full bg-violet-500/10 text-violet-600">
          {{ inventories.find(i => i.id === inventoryId)?.name || 'Filtered' }}
        </span>
        <span v-if="statusFilter !== 'all'" class="text-xs px-2 py-0.5 rounded-full bg-amber-500/10 text-amber-600">
          {{ statusFilter === 'completed' ? 'Completed only' : 'Skipped only' }}
        </span>
        <span v-if="selectedTagIds.length > 0" class="text-xs px-2 py-0.5 rounded-full bg-pink-500/10 text-pink-600">
          {{ selectedTagIds.length }} tag{{ selectedTagIds.length !== 1 ? 's' : '' }}
        </span>
      </div>
    </CardHeader>

    <CardContent>
      <!-- Loading state -->
      <div v-if="loading" class="h-48 flex items-center justify-center">
        <div class="h-5 w-5 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
      </div>

      <!-- Error state -->
      <div 
        v-else-if="hasError" 
        class="h-48 flex flex-col items-center justify-center text-muted-foreground text-sm gap-2"
      >
        <span>Failed to load analytics</span>
        <button 
          @click="fetchAnalytics" 
          class="text-xs text-primary hover:underline"
        >
          Retry
        </button>
      </div>

      <!-- No data state -->
      <div 
        v-else-if="!analyticsData || analyticsData.total_entries === 0" 
        class="h-48 flex items-center justify-center text-muted-foreground text-sm"
      >
        No habit data for this period
      </div>

      <!-- Charts -->
      <div v-else class="h-48">
        <Line
          v-if="reportType === 'completion_rate'"
          :data="completionRateChartData"
          :options="chartOptions"
        />
        <Bar
          v-else-if="reportType === 'habits_per_day'"
          :data="habitsPerDayChartData"
          :options="chartOptions"
        />
        <div v-else-if="reportType === 'skip_reasons'" class="flex items-center justify-center h-full">
          <div class="w-40 h-40">
            <Doughnut
              :data="skipReasonsChartData"
              :options="doughnutOptions"
            />
          </div>
        </div>
        <Bar
          v-else-if="reportType === 'streak_chart'"
          :data="streakChartData"
          :options="{ ...chartOptions, indexAxis: 'y' as const }"
        />
        <Bar
          v-else-if="reportType === 'weekly_trends'"
          :data="weeklyTrendsChartData"
          :options="chartOptions"
        />
      </div>
    </CardContent>
  </Card>
</template>
