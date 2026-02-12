import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { BudgetSource, BudgetEntry, BudgetSummary } from '@/types'
import { api } from '@/services/api'
import { format, startOfMonth, endOfMonth, startOfWeek, endOfWeek, addWeeks, subWeeks } from 'date-fns'
import { fetchIfStale, invalidate, invalidatePrefix } from '@/utils/prefetch'

export const useBudgetStore = defineStore('budget', () => {
  const sources = ref<BudgetSource[]>([])
  const entries = ref<BudgetEntry[]>([])
  const summary = ref<BudgetSummary | null>(null)
  const loading = ref(false)
  const currentMonth = ref(new Date())
  const currentWeek = ref(new Date())
  const viewMode = ref<'week' | 'month'>('month')

  const incomeSources = computed(() =>
    sources.value.filter(s => s.type === 'income')
  )

  const expenseSources = computed(() =>
    sources.value.filter(s => s.type === 'expense')
  )

  const entriesByDate = computed(() => {
    const grouped: Record<string, BudgetEntry[]> = {}
    for (const entry of entries.value) {
      if (!grouped[entry.date]) grouped[entry.date] = []
      grouped[entry.date].push(entry)
    }
    return grouped
  })

  const filterTags = ref<string[]>([])

  async function fetchSources() {
    return fetchIfStale('budget:sources', async () => {
      loading.value = true
      try {
        const response = await api.listSources()
        sources.value = response.data
      } finally {
        loading.value = false
      }
    })
  }

  async function createSource(source: Partial<BudgetSource>) {
    const response = await api.createSource(source)
    sources.value.push(response.data)
    invalidate('budget:sources')
    return response.data
  }

  async function updateSource(id: string, updates: Partial<BudgetSource>) {
    const response = await api.updateSource(id, updates)
    const index = sources.value.findIndex(s => s.id === id)
    if (index !== -1) {
      sources.value[index] = response.data
    }
    invalidate('budget:sources')
    return response.data
  }

  async function deleteSource(id: string) {
    await api.deleteSource(id)
    sources.value = sources.value.filter(s => s.id !== id)
    invalidate('budget:sources')
  }

  async function fetchEntries(startDate?: Date, endDate?: Date) {
    loading.value = true
    try {
      const params: { start_date?: string; end_date?: string; tag_ids?: string[] } = {}
      if (startDate) params.start_date = format(startDate, 'yyyy-MM-dd')
      if (endDate) params.end_date = format(endDate, 'yyyy-MM-dd')
      if (filterTags.value.length > 0) params.tag_ids = filterTags.value

      const response = await api.listEntries(params)
      entries.value = response.data
    } finally {
      loading.value = false
    }
  }

  async function fetchMonthEntries() {
    const start = startOfMonth(currentMonth.value)
    const end = endOfMonth(currentMonth.value)
    const key = `budget:entries:month:${format(start, 'yyyy-MM-dd')}`
    return fetchIfStale(key, async () => {
      await fetchEntries(start, end)
    })
  }

  async function fetchWeekEntries() {
    const start = startOfWeek(currentWeek.value, { weekStartsOn: 1 })
    const end = endOfWeek(currentWeek.value, { weekStartsOn: 1 })
    const key = `budget:entries:week:${format(start, 'yyyy-MM-dd')}`
    return fetchIfStale(key, async () => {
      await fetchEntries(start, end)
    })
  }

  async function fetchCurrentViewEntries() {
    if (viewMode.value === 'week') {
      await fetchWeekEntries()
    } else {
      await fetchMonthEntries()
    }
  }

  async function createEntry(entry: Partial<BudgetEntry> & { tag_ids?: string[] }) {
    const response = await api.createEntry(entry)
    entries.value.push(response.data)
    invalidatePrefix('budget:entries')
    invalidate('budget:summary')
    // Refresh summary
    await fetchSummary()
    return response.data
  }

  async function updateEntry(id: string, updates: Partial<BudgetEntry> & { tag_ids?: string[] }) {
    const response = await api.updateEntry(id, updates)
    const index = entries.value.findIndex(e => e.id === id)
    if (index !== -1) {
      entries.value[index] = response.data
    }
    invalidatePrefix('budget:entries')
    invalidate('budget:summary')
    await fetchSummary()
    return response.data
  }

  async function deleteEntry(id: string) {
    await api.deleteEntry(id)
    entries.value = entries.value.filter(e => e.id !== id)
    invalidatePrefix('budget:entries')
    invalidate('budget:summary')
    await fetchSummary()
  }

  async function fetchSummary(year?: number, month?: number) {
    const y = year || currentMonth.value.getFullYear()
    const m = month || currentMonth.value.getMonth() + 1
    const key = `budget:summary:${y}-${m}`
    return fetchIfStale(key, async () => {
      const response = await api.getBudgetSummary(y, m)
      summary.value = response.data
    })
  }

  function setCurrentMonth(date: Date) {
    currentMonth.value = date
  }

  function nextMonth() {
    const next = new Date(currentMonth.value)
    next.setMonth(next.getMonth() + 1)
    currentMonth.value = next
  }

  function prevMonth() {
    const prev = new Date(currentMonth.value)
    prev.setMonth(prev.getMonth() - 1)
    currentMonth.value = prev
  }

  function nextWeek() {
    currentWeek.value = addWeeks(currentWeek.value, 1)
  }

  function prevWeek() {
    currentWeek.value = subWeeks(currentWeek.value, 1)
  }

  function goToTodayWeek() {
    currentWeek.value = new Date()
  }

  function toggleViewMode() {
    viewMode.value = viewMode.value === 'week' ? 'month' : 'week'
  }

  return {
    sources,
    entries,
    summary,
    loading,
    currentMonth,
    currentWeek,
    viewMode,
    incomeSources,
    expenseSources,
    entriesByDate,
    filterTags,
    fetchSources,
    createSource,
    updateSource,
    deleteSource,
    fetchEntries,
    fetchMonthEntries,
    fetchWeekEntries,
    fetchCurrentViewEntries,
    createEntry,
    updateEntry,
    deleteEntry,
    fetchSummary,
    setCurrentMonth,
    nextMonth,
    prevMonth,
    nextWeek,
    prevWeek,
    goToTodayWeek,
    toggleViewMode
  }
})
