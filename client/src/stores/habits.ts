import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Habit, HabitCompletion, HabitAnalytics, HabitInventory } from '@/types'
import { api } from '@/services/api'

export interface HabitWithStatus extends Habit {
  completed_today: boolean
}

export const useHabitsStore = defineStore('habits', () => {
  const habits = ref<HabitWithStatus[]>([])
  const completions = ref<Map<string, HabitCompletion[]>>(new Map())
  const analytics = ref<HabitAnalytics | null>(null)
  const loading = ref(false)
  const analyticsLoading = ref(false)
  const habitInventories = ref<HabitInventory[]>([])

  const dailyHabits = computed(() =>
    habits.value.filter(h => h.frequency === 'daily')
  )

  const weeklyHabits = computed(() =>
    habits.value.filter(h => h.frequency === 'weekly')
  )

  const completedToday = computed(() =>
    habits.value.filter(h => h.completed_today)
  )

  const pendingToday = computed(() =>
    habits.value.filter(h => !h.completed_today)
  )

  const totalStreak = computed(() =>
    habits.value.reduce((sum, h) => sum + h.streak_count, 0)
  )

  const filterTags = ref<string[]>([])

  async function fetchHabits() {
    loading.value = true
    try {
      const response = await api.listHabits({ tag_ids: filterTags.value.length > 0 ? filterTags.value : undefined })
      habits.value = response.data as HabitWithStatus[]
    } finally {
      loading.value = false
    }
  }

  async function createHabit(habit: Partial<Habit> & { tag_ids?: string[] }) {
    const response = await api.createHabit(habit)
    await fetchHabits()
    return response.data
  }

  async function updateHabit(id: string, updates: Partial<Habit> & { tag_ids?: string[] }) {
    const response = await api.updateHabit(id, updates)
    await fetchHabits()
    return response.data
  }

  async function deleteHabit(id: string) {
    await api.deleteHabit(id)
    habits.value = habits.value.filter(h => h.id !== id)
  }

  async function completeHabit(id: string) {
    // Optimistic update
    const habit = habits.value.find(h => h.id === id)
    if (habit) {
      habit.completed_today = true
      habit.streak_count++
    }

    try {
      await api.completeHabit(id)
      // Refresh habits to get updated streak data
      await fetchHabits()
    } catch (error) {
      // Revert on error
      if (habit) {
        habit.completed_today = false
        habit.streak_count--
      }
      throw error
    }
  }

  async function uncompleteHabit(id: string) {
    // Optimistic update
    const habit = habits.value.find(h => h.id === id)
    const oldStreak = habit?.streak_count || 0
    if (habit) {
      habit.completed_today = false
    }

    try {
      await api.uncompleteHabit(id)
      // Re-fetch to get correct streak
      await fetchHabits()
    } catch (error) {
      // Revert on error
      if (habit) {
        habit.completed_today = true
        habit.streak_count = oldStreak
      }
      throw error
    }
  }

  async function skipHabit(id: string, reason: string) {
    // Optimistic update
    const habit = habits.value.find(h => h.id === id)
    if (habit) {
      habit.completed_today = true // Mark as "done" for the day (skipped counts as done)
    }

    try {
      const response = await api.skipHabit(id, reason)
      // Refresh habits to get updated data
      await fetchHabits()
      return response.data
    } catch (error) {
      // Revert on error
      if (habit) {
        habit.completed_today = false
      }
      throw error
    }
  }

  async function fetchHabitAnalytics(params?: {
    habit_id?: string
    inventory_id?: string
    start_date?: string
    end_date?: string
    tag_ids?: string[]
    status_filter?: string
  }) {
    analyticsLoading.value = true
    try {
      const response = await api.getHabitAnalytics(params)
      analytics.value = response.data
      return response.data
    } finally {
      analyticsLoading.value = false
    }
  }

  async function fetchCompletions(habitId: string, startDate?: string, endDate?: string) {
    const response = await api.getHabitCompletions(habitId, { start_date: startDate, end_date: endDate })
    completions.value.set(habitId, response.data)
    return response.data
  }

  function getCompletions(habitId: string): HabitCompletion[] {
    return completions.value.get(habitId) || []
  }

  // Habit Inventories
  async function fetchHabitInventories() {
    const response = await api.listHabitInventories()
    habitInventories.value = response.data
    return response.data
  }

  async function createHabitInventory(inventory: Partial<HabitInventory>) {
    const response = await api.createHabitInventory(inventory)
    await fetchHabitInventories()
    return response.data
  }

  async function updateHabitInventory(id: string, updates: Partial<HabitInventory>) {
    const response = await api.updateHabitInventory(id, updates)
    await fetchHabitInventories()
    return response.data
  }

  async function deleteHabitInventory(id: string) {
    await api.deleteHabitInventory(id)
    habitInventories.value = habitInventories.value.filter(i => i.id !== id)
  }

  // Computed: habits grouped by inventory
  const habitsByInventory = computed(() => {
    const grouped = new Map<string | null, HabitWithStatus[]>()

    // Group habits by inventory_id
    for (const habit of habits.value) {
      const key = habit.inventory_id
      if (!grouped.has(key)) {
        grouped.set(key, [])
      }
      grouped.get(key)!.push(habit)
    }

    return grouped
  })

  return {
    habits,
    completions,
    analytics,
    loading,
    analyticsLoading,
    habitInventories,
    dailyHabits,
    weeklyHabits,
    completedToday,
    pendingToday,
    totalStreak,
    habitsByInventory,
    fetchHabits,
    createHabit,
    updateHabit,
    deleteHabit,
    completeHabit,
    uncompleteHabit,
    skipHabit,
    fetchHabitAnalytics,
    fetchCompletions,
    getCompletions,
    filterTags,
    fetchHabitInventories,
    createHabitInventory,
    updateHabitInventory,
    deleteHabitInventory
  }
})

