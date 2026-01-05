import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { BudgetSource, BudgetEntry, BudgetSummary } from '@/types'
import { api } from '@/services/api'
import { format, startOfMonth, endOfMonth } from 'date-fns'

export const useBudgetStore = defineStore('budget', () => {
  const sources = ref<BudgetSource[]>([])
  const entries = ref<BudgetEntry[]>([])
  const summary = ref<BudgetSummary | null>(null)
  const loading = ref(false)
  const currentMonth = ref(new Date())

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

  async function fetchSources() {
    loading.value = true
    try {
      const response = await api.listSources()
      sources.value = response.data
    } finally {
      loading.value = false
    }
  }

  async function createSource(source: Partial<BudgetSource>) {
    const response = await api.createSource(source)
    sources.value.push(response.data)
    return response.data
  }

  async function updateSource(id: string, updates: Partial<BudgetSource>) {
    const response = await api.updateSource(id, updates)
    const index = sources.value.findIndex(s => s.id === id)
    if (index !== -1) {
      sources.value[index] = response.data
    }
    return response.data
  }

  async function deleteSource(id: string) {
    await api.deleteSource(id)
    sources.value = sources.value.filter(s => s.id !== id)
  }

  async function fetchEntries(startDate?: Date, endDate?: Date) {
    loading.value = true
    try {
      const params: { start_date?: string; end_date?: string } = {}
      if (startDate) params.start_date = format(startDate, 'yyyy-MM-dd')
      if (endDate) params.end_date = format(endDate, 'yyyy-MM-dd')
      
      const response = await api.listEntries(params)
      entries.value = response.data
    } finally {
      loading.value = false
    }
  }

  async function fetchMonthEntries() {
    const start = startOfMonth(currentMonth.value)
    const end = endOfMonth(currentMonth.value)
    await fetchEntries(start, end)
  }

  async function createEntry(entry: Partial<BudgetEntry>) {
    const response = await api.createEntry(entry)
    entries.value.push(response.data)
    // Refresh summary
    await fetchSummary()
    return response.data
  }

  async function updateEntry(id: string, updates: Partial<BudgetEntry>) {
    const response = await api.updateEntry(id, updates)
    const index = entries.value.findIndex(e => e.id === id)
    if (index !== -1) {
      entries.value[index] = response.data
    }
    await fetchSummary()
    return response.data
  }

  async function deleteEntry(id: string) {
    await api.deleteEntry(id)
    entries.value = entries.value.filter(e => e.id !== id)
    await fetchSummary()
  }

  async function fetchSummary(year?: number, month?: number) {
    const y = year || currentMonth.value.getFullYear()
    const m = month || currentMonth.value.getMonth() + 1
    
    const response = await api.getBudgetSummary(y, m)
    summary.value = response.data
    return response.data
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

  return {
    sources,
    entries,
    summary,
    loading,
    currentMonth,
    incomeSources,
    expenseSources,
    entriesByDate,
    fetchSources,
    createSource,
    updateSource,
    deleteSource,
    fetchEntries,
    fetchMonthEntries,
    createEntry,
    updateEntry,
    deleteEntry,
    fetchSummary,
    setCurrentMonth,
    nextMonth,
    prevMonth
  }
})

