import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Habit, HabitCompletion } from '@/types'
import { api } from '@/services/api'

export interface HabitWithStatus extends Habit {
  completed_today: boolean
}

export const useHabitsStore = defineStore('habits', () => {
  const habits = ref<HabitWithStatus[]>([])
  const completions = ref<Map<string, HabitCompletion[]>>(new Map())
  const loading = ref(false)

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

  async function fetchHabits() {
    loading.value = true
    try {
      const response = await api.listHabits()
      habits.value = response.data as HabitWithStatus[]
    } finally {
      loading.value = false
    }
  }

  async function createHabit(habit: Partial<Habit>) {
    const response = await api.createHabit(habit)
    habits.value.unshift(response.data as HabitWithStatus)
    return response.data
  }

  async function updateHabit(id: string, updates: Partial<Habit>) {
    const response = await api.updateHabit(id, updates)
    const index = habits.value.findIndex(h => h.id === id)
    if (index !== -1) {
      habits.value[index] = response.data as HabitWithStatus
    }
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

  async function fetchCompletions(habitId: string, startDate?: string, endDate?: string) {
    const response = await api.getHabitCompletions(habitId, { start_date: startDate, end_date: endDate })
    completions.value.set(habitId, response.data)
    return response.data
  }

  function getCompletions(habitId: string): HabitCompletion[] {
    return completions.value.get(habitId) || []
  }

  return {
    habits,
    completions,
    loading,
    dailyHabits,
    weeklyHabits,
    completedToday,
    pendingToday,
    totalStreak,
    fetchHabits,
    createHabit,
    updateHabit,
    deleteHabit,
    completeHabit,
    uncompleteHabit,
    fetchCompletions,
    getCompletions
  }
})

