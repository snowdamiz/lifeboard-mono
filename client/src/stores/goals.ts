import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Goal, GoalCategory, GoalHistoryItem, Milestone } from '@/types'
import { api } from '@/services/api'

export const useGoalsStore = defineStore('goals', () => {
  const goals = ref<Goal[]>([])
  // const categories = ref<GoalCategory[]>([]) - Removed

  const currentGoal = ref<Goal | null>(null)
  const loading = ref(false)

  const activeGoals = computed(() =>
    goals.value.filter(g => g.status === 'in_progress' || g.status === 'not_started')
  )

  async function updateGoalStatusBasedOnProgress(goalId: string) {
    const goal = goals.value.find(g => g.id === goalId)
    // Don't auto-update if abandoned
    if (!goal || goal.status === 'abandoned') return

    let newStatus = goal.status
    if (goal.progress === 100 && goal.status !== 'completed') {
      newStatus = 'completed'
    } else if (goal.progress === 0 && goal.status !== 'not_started') {
      // Only revert to not_started if it was in_progress or completed
      if (goal.status === 'in_progress' || goal.status === 'completed') {
        newStatus = 'not_started'
      }
    } else if (goal.progress > 0 && goal.progress < 100 && goal.status !== 'in_progress') {
      newStatus = 'in_progress'
    }

    if (newStatus !== goal.status) {
      await updateGoal(goalId, { status: newStatus as any })
    }
  }

  const completedGoals = computed(() =>
    goals.value.filter(g => g.status === 'completed')
  )




  const filterTags = ref<string[]>([])

  async function fetchGoals(params?: { status?: string; category_id?: string; tag_ids?: string[] }) {
    loading.value = true
    try {
      const requestParams = { ...params }
      if (filterTags.value.length > 0) {
        requestParams.tag_ids = filterTags.value
      }
      const response = await api.listGoals(requestParams)
      goals.value = response.data
    } finally {
      loading.value = false
    }
  }


  async function fetchGoal(id: string) {
    loading.value = true
    try {
      const response = await api.getGoal(id)
      currentGoal.value = response.data
      return response.data
    } finally {
      loading.value = false
    }
  }

  async function createGoal(goal: Partial<Goal>) {
    const response = await api.createGoal(goal)
    goals.value.unshift(response.data)
    return response.data
  }

  async function updateGoal(id: string, updates: Partial<Goal>) {
    const response = await api.updateGoal(id, updates)
    const index = goals.value.findIndex(g => g.id === id)
    if (index !== -1) {
      goals.value[index] = response.data
    }
    if (currentGoal.value?.id === id) {
      currentGoal.value = response.data
    }
    return response.data
  }

  async function deleteGoal(id: string) {
    await api.deleteGoal(id)
    goals.value = goals.value.filter(g => g.id !== id)
    if (currentGoal.value?.id === id) {
      currentGoal.value = null
    }
  }

  async function addMilestone(goalId: string, title: string) {
    const response = await api.addMilestone(goalId, { title })
    const goal = goals.value.find(g => g.id === goalId)
    if (goal) {
      goal.milestones.push(response.data)
    }
    if (currentGoal.value?.id === goalId) {
      currentGoal.value.milestones.push(response.data)
    }
    // Re-fetch to get updated progress
    await fetchGoal(goalId)
    await updateGoalStatusBasedOnProgress(goalId)
    return response.data
  }

  async function updateMilestone(goalId: string, milestoneId: string, updates: Partial<Milestone>) {
    const response = await api.updateMilestone(goalId, milestoneId, updates)
    // Update in local state
    const goal = goals.value.find(g => g.id === goalId)
    if (goal) {
      const index = goal.milestones.findIndex(m => m.id === milestoneId)
      if (index !== -1) {
        goal.milestones[index] = response.data
      }
    }
    // Re-fetch to get updated progress
    await fetchGoal(goalId)
    await updateGoalStatusBasedOnProgress(goalId)
    return response.data
  }

  async function toggleMilestone(goalId: string, milestoneId: string) {
    // Find the milestone in currentGoal (used by detail view)
    const currentMilestone = currentGoal.value?.id === goalId
      ? currentGoal.value.milestones.find(m => m.id === milestoneId)
      : null
    const previousCurrentCompleted = currentMilestone?.completed

    // Find the milestone in goals list
    const goal = goals.value.find(g => g.id === goalId)
    const listMilestone = goal?.milestones.find(m => m.id === milestoneId)
    const previousListCompleted = listMilestone?.completed

    // Optimistic update for both currentGoal and goals list
    if (currentMilestone) {
      currentMilestone.completed = !currentMilestone.completed
      currentMilestone.completed_at = currentMilestone.completed ? new Date().toISOString() : null
    }
    if (listMilestone) {
      listMilestone.completed = !listMilestone.completed
      listMilestone.completed_at = listMilestone.completed ? new Date().toISOString() : null
    }

    try {
      // Call the dedicated toggle endpoint
      await api.toggleMilestone(goalId, milestoneId)
      // Re-fetch to get updated progress
      await fetchGoal(goalId)
      await updateGoalStatusBasedOnProgress(goalId)
    } catch (error) {
      // Revert on error
      if (currentMilestone && previousCurrentCompleted !== undefined) {
        currentMilestone.completed = previousCurrentCompleted
        currentMilestone.completed_at = previousCurrentCompleted ? currentMilestone.completed_at : null
      }
      if (listMilestone && previousListCompleted !== undefined) {
        listMilestone.completed = previousListCompleted
        listMilestone.completed_at = previousListCompleted ? listMilestone.completed_at : null
      }
      throw error
    }
  }

  async function deleteMilestone(goalId: string, milestoneId: string) {
    await api.deleteMilestone(goalId, milestoneId)
    const goal = goals.value.find(g => g.id === goalId)
    if (goal) {
      goal.milestones = goal.milestones.filter(m => m.id !== milestoneId)
    }
    if (currentGoal.value?.id === goalId) {
      currentGoal.value.milestones = currentGoal.value.milestones.filter(m => m.id !== milestoneId)
    }
    // Re-fetch to get updated progress
    await fetchGoal(goalId)
    await updateGoalStatusBasedOnProgress(goalId)
  }

  async function updateGoalTags(goalId: string, tagIds: string[]) {
    const response = await api.updateGoalTags(goalId, tagIds)
    const index = goals.value.findIndex(g => g.id === goalId)
    if (index !== -1) {
      goals.value[index] = response.data
    }
    if (currentGoal.value?.id === goalId) {
      currentGoal.value = response.data
    }
    return response.data
  }

  async function fetchGoalHistory(goalId: string): Promise<GoalHistoryItem[]> {
    const response = await api.getGoalHistory(goalId)
    return response.data
  }

  return {
    goals,
    currentGoal,
    loading,
    activeGoals,
    completedGoals,
    filterTags,
    fetchGoals,
    fetchGoal,
    createGoal,
    updateGoal,
    deleteGoal,
    updateGoalTags,
    fetchGoalHistory,
    addMilestone,
    updateMilestone,
    toggleMilestone,
    deleteMilestone
  }
})

