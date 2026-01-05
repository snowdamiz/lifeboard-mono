import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Goal, GoalCategory, GoalHistoryItem, Milestone } from '@/types'
import { api } from '@/services/api'

export const useGoalsStore = defineStore('goals', () => {
  const goals = ref<Goal[]>([])
  const categories = ref<GoalCategory[]>([])
  const currentGoal = ref<Goal | null>(null)
  const loading = ref(false)

  const activeGoals = computed(() => 
    goals.value.filter(g => g.status === 'in_progress' || g.status === 'not_started')
  )

  const completedGoals = computed(() => 
    goals.value.filter(g => g.status === 'completed')
  )

  const goalsByCategory = computed(() => {
    const grouped: Record<string, Goal[]> = {}
    for (const goal of goals.value) {
      const category = goal.goal_category?.name || goal.category || 'Uncategorized'
      if (!grouped[category]) grouped[category] = []
      grouped[category].push(goal)
    }
    return grouped
  })

  // Flatten categories with subcategories for select dropdowns
  const flatCategories = computed(() => {
    const result: { id: string; name: string; isSubcategory: boolean; parentName?: string }[] = []
    for (const cat of categories.value) {
      result.push({ id: cat.id, name: cat.name, isSubcategory: false })
      if (cat.subcategories) {
        for (const sub of cat.subcategories) {
          result.push({ id: sub.id, name: sub.name, isSubcategory: true, parentName: cat.name })
        }
      }
    }
    return result
  })

  async function fetchCategories() {
    const response = await api.listGoalCategories()
    categories.value = response.data
  }

  async function createCategory(category: Partial<GoalCategory>) {
    const response = await api.createGoalCategory(category)
    // Add to appropriate place
    if (response.data.parent_id) {
      const parent = categories.value.find(c => c.id === response.data.parent_id)
      if (parent) {
        parent.subcategories = [...(parent.subcategories || []), response.data]
      }
    } else {
      categories.value.push(response.data)
    }
    return response.data
  }

  async function updateCategory(id: string, updates: Partial<GoalCategory>) {
    const response = await api.updateGoalCategory(id, updates)
    // Re-fetch to ensure proper structure
    await fetchCategories()
    return response.data
  }

  async function deleteCategory(id: string) {
    await api.deleteGoalCategory(id)
    await fetchCategories()
  }

  async function fetchGoals(params?: { status?: string; category_id?: string; tag_ids?: string[] }) {
    loading.value = true
    try {
      const response = await api.listGoals(params)
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
    categories,
    currentGoal,
    loading,
    activeGoals,
    completedGoals,
    goalsByCategory,
    flatCategories,
    fetchCategories,
    createCategory,
    updateCategory,
    deleteCategory,
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

