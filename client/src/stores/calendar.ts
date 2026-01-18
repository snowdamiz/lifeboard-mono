import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Task, TaskStep } from '@/types'
import { api } from '@/services/api'
import { format, startOfWeek, endOfWeek, startOfMonth, endOfMonth, addDays, addMonths, parseISO, getDay } from 'date-fns'

export const useCalendarStore = defineStore('calendar', () => {
  const tasks = ref<Task[]>([])
  const todaysTasks = ref<Task[]>([])
  const loading = ref(false)
  const currentDate = ref(new Date())
  const viewMode = ref<'day' | 'week' | 'month'>('week')
  const filterTags = ref<string[]>([])

  // Week view computed properties
  const weekStart = computed(() => startOfWeek(currentDate.value, { weekStartsOn: 1 }))
  const weekEnd = computed(() => endOfWeek(currentDate.value, { weekStartsOn: 1 }))

  const weekDays = computed(() => {
    const days = []
    for (let i = 0; i < 7; i++) {
      days.push(addDays(weekStart.value, i))
    }
    return days
  })

  // Month view computed properties
  const monthStart = computed(() => startOfMonth(currentDate.value))
  const monthEnd = computed(() => endOfMonth(currentDate.value))

  const monthDays = computed(() => {
    const days: Date[] = []

    // Get the first day of the month
    const firstDay = monthStart.value
    // Get what day of week it is (0 = Sunday, 1 = Monday, etc.)
    let firstDayOfWeek = getDay(firstDay)
    // Adjust for Monday start (0 = Monday, 6 = Sunday)
    firstDayOfWeek = firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1

    // Add padding days from previous month
    for (let i = firstDayOfWeek - 1; i >= 0; i--) {
      days.push(addDays(firstDay, -i - 1))
    }

    // Add all days of the current month
    let currentDay = firstDay
    while (currentDay <= monthEnd.value) {
      days.push(currentDay)
      currentDay = addDays(currentDay, 1)
    }

    // Add padding days from next month to complete the grid (6 rows * 7 days = 42)
    const remainingDays = 42 - days.length
    for (let i = 1; i <= remainingDays; i++) {
      days.push(addDays(monthEnd.value, i))
    }

    return days
  })

  const tasksByDate = computed(() => {
    const grouped: Record<string, Task[]> = {}
    for (const task of tasks.value) {
      const date = task.date || 'unscheduled'
      if (!grouped[date]) grouped[date] = []
      grouped[date].push(task)
    }
    // Sort by priority within each date
    for (const date in grouped) {
      grouped[date].sort((a, b) => a.priority - b.priority)
    }
    return grouped
  })

  async function fetchTasks(startDate?: Date, endDate?: Date) {
    loading.value = true
    try {
      const params: { start_date?: string; end_date?: string; tag_ids?: string } = {}
      if (startDate) params.start_date = format(startDate, 'yyyy-MM-dd')
      if (endDate) params.end_date = format(endDate, 'yyyy-MM-dd')
      if (filterTags.value.length > 0) params.tag_ids = filterTags.value.join(',')

      const response = await api.listTasks(params)
      tasks.value = response.data
    } finally {
      loading.value = false
    }
  }

  async function fetchWeekTasks() {
    await fetchTasks(weekStart.value, weekEnd.value)
  }

  async function fetchMonthTasks() {
    // Fetch tasks for the entire visible month grid (including padding days)
    const firstVisible = monthDays.value[0]
    const lastVisible = monthDays.value[monthDays.value.length - 1]
    await fetchTasks(firstVisible, lastVisible)
  }

  async function fetchCurrentViewTasks() {
    if (viewMode.value === 'month') {
      await fetchMonthTasks()
    } else {
      await fetchWeekTasks()
    }
  }

  async function fetchTodayTasks() {
    const today = format(new Date(), 'yyyy-MM-dd')
    const params: any = { start_date: today, end_date: today }
    if (filterTags.value.length > 0) params.tag_ids = filterTags.value.join(',')

    const response = await api.listTasks(params)
    todaysTasks.value = response.data
  }

  async function createTask(task: Partial<Task> & { tag_ids?: string[] }) {
    const response = await api.createTask(task)
    tasks.value.push(response.data)
    return response.data
  }

  async function updateTask(id: string, updates: Partial<Task> & { tag_ids?: string[] }) {
    const response = await api.updateTask(id, updates)
    const index = tasks.value.findIndex(t => t.id === id)
    if (index !== -1) {
      tasks.value[index] = response.data
    }
    return response.data
  }

  async function deleteTask(id: string) {
    await api.deleteTask(id)
    tasks.value = tasks.value.filter(t => t.id !== id)
  }

  async function addStep(taskId: string, content: string) {
    const response = await api.createTaskStep(taskId, { content })
    const task = tasks.value.find(t => t.id === taskId)
    if (task) {
      task.steps.push(response.data)
    }
    return response.data
  }

  async function updateStep(taskId: string, stepId: string, updates: Partial<TaskStep>) {
    const response = await api.updateTaskStep(taskId, stepId, updates)
    const task = tasks.value.find(t => t.id === taskId)
    if (task) {
      const index = task.steps.findIndex(s => s.id === stepId)
      if (index !== -1) {
        task.steps[index] = response.data
      }
    }
    return response.data
  }

  async function deleteStep(taskId: string, stepId: string) {
    await api.deleteTaskStep(taskId, stepId)
    const task = tasks.value.find(t => t.id === taskId)
    if (task) {
      task.steps = task.steps.filter(s => s.id !== stepId)
    }
  }

  async function reorderTasks(taskIds: string[]) {
    if (taskIds.length === 0) return
    await api.reorderTasks(taskIds[0], taskIds)
    // Re-fetch to get updated priorities
    await fetchWeekTasks()
  }

  function setCurrentDate(date: Date) {
    currentDate.value = date
  }

  function setViewMode(mode: 'day' | 'week' | 'month') {
    viewMode.value = mode
  }

  function goToToday() {
    currentDate.value = new Date()
  }

  function nextPeriod() {
    if (viewMode.value === 'month') {
      currentDate.value = addMonths(currentDate.value, 1)
    } else if (viewMode.value === 'week') {
      currentDate.value = addDays(currentDate.value, 7)
    } else {
      currentDate.value = addDays(currentDate.value, 1)
    }
  }

  function prevPeriod() {
    if (viewMode.value === 'month') {
      currentDate.value = addMonths(currentDate.value, -1)
    } else if (viewMode.value === 'week') {
      currentDate.value = addDays(currentDate.value, -7)
    } else {
      currentDate.value = addDays(currentDate.value, -1)
    }
  }

  return {
    tasks,
    todaysTasks,
    loading,
    currentDate,
    viewMode,
    weekStart,
    weekEnd,
    weekDays,
    monthStart,
    monthEnd,
    monthDays,
    tasksByDate,
    fetchTasks,
    fetchWeekTasks,
    fetchMonthTasks,
    fetchCurrentViewTasks,
    fetchTodayTasks,
    createTask,
    updateTask,
    deleteTask,
    addStep,
    updateStep,
    deleteStep,
    reorderTasks,
    setCurrentDate,
    setViewMode,
    goToToday,
    nextPeriod,
    prevPeriod,
    filterTags
  }
})

