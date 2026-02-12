import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { Task, TaskStep, Trip } from '@/types'
import { api } from '@/services/api'
import { format, startOfWeek, endOfWeek, startOfMonth, endOfMonth, addDays, addMonths, parseISO, getDay } from 'date-fns'
import { fetchIfStale, invalidate } from '@/utils/prefetch'

export const useCalendarStore = defineStore('calendar', () => {
  const tasks = ref<Task[]>([])
  const trips = ref<Trip[]>([])
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

  // Group trips by date (using trip_start date)
  const tripsByDate = computed(() => {
    const grouped: Record<string, Trip[]> = {}
    console.log('[DEBUG] tripsByDate computing with trips:', trips.value.length, trips.value)
    for (const trip of trips.value) {
      // Use trip_start date, fallback to inserted_at
      const dateStr = trip.trip_start?.split('T')[0] || trip.inserted_at?.split('T')[0] || 'unscheduled'
      console.log('[DEBUG] Trip date:', dateStr, 'trip:', trip.id, trip)
      if (!grouped[dateStr]) grouped[dateStr] = []
      grouped[dateStr].push(trip)
    }
    console.log('[DEBUG] tripsByDate result:', grouped)
    return grouped
  })

  async function fetchTasks(startDate?: Date, endDate?: Date) {
    loading.value = true
    try {
      const params: { start_date?: string; end_date?: string; tag_ids?: string } = {}
      if (startDate) params.start_date = format(startDate, 'yyyy-MM-dd')
      if (endDate) params.end_date = format(endDate, 'yyyy-MM-dd')
      if (filterTags.value.length > 0) params.tag_ids = filterTags.value.join(',')

      console.log('[DEBUG] fetchTasks params:', params)
      const response = await api.listTasks(params)
      const tripTasks = response.data.filter((t: any) => t.trip_id)
      console.log('[DEBUG] fetchTasks got', response.data.length, 'tasks,', tripTasks.length, 'with trip_id:', tripTasks.map((t: any) => ({ id: t.id, title: t.title, date: t.date, trip_id: t.trip_id })))
      tasks.value = response.data
    } finally {
      loading.value = false
    }
  }

  async function fetchTripsForPeriod(startDate: Date, endDate: Date) {
    try {
      const params = {
        start_date: format(startDate, 'yyyy-MM-dd'),
        end_date: format(endDate, 'yyyy-MM-dd')
      }
      console.log('[DEBUG] fetchTripsForPeriod params:', params)
      const response = await api.listTrips(params)
      console.log('[DEBUG] fetchTripsForPeriod response:', response)
      trips.value = response.data
    } catch (error) {
      console.error('Failed to fetch trips:', error)
      trips.value = []
    }
  }

  async function fetchWeekTasks() {
    const key = `calendar:week:${format(weekStart.value, 'yyyy-MM-dd')}`
    return fetchIfStale(key, async () => {
      await Promise.all([
        fetchTasks(weekStart.value, weekEnd.value),
        fetchTripsForPeriod(weekStart.value, weekEnd.value)
      ])
    })
  }

  async function fetchMonthTasks() {
    // Fetch tasks and trips for the entire visible month grid (including padding days)
    const firstVisible = monthDays.value[0]
    const lastVisible = monthDays.value[monthDays.value.length - 1]
    const key = `calendar:month:${format(firstVisible, 'yyyy-MM-dd')}`
    return fetchIfStale(key, async () => {
      await Promise.all([
        fetchTasks(firstVisible, lastVisible),
        fetchTripsForPeriod(firstVisible, lastVisible)
      ])
    })
  }

  async function fetchCurrentViewTasks() {
    if (viewMode.value === 'month') {
      await fetchMonthTasks()
    } else {
      await fetchWeekTasks()
    }
  }

  async function fetchTodayTasks() {
    return fetchIfStale('calendar:today', async () => {
      const today = format(new Date(), 'yyyy-MM-dd')
      const params: any = { start_date: today, end_date: today }
      if (filterTags.value.length > 0) params.tag_ids = filterTags.value.join(',')

      const response = await api.listTasks(params)
      todaysTasks.value = response.data
    })
  }

  async function createTask(task: Partial<Task> & { tag_ids?: string[] }) {
    console.log('[DEBUG] calendarStore.createTask sending:', JSON.stringify(task, null, 2))
    try {
      const response = await api.createTask(task)
      console.log('[DEBUG] calendarStore.createTask response:', JSON.stringify(response.data, null, 2))
      tasks.value.push(response.data)
      invalidate('calendar:today')
      return response.data
    } catch (error) {
      console.error('[DEBUG] calendarStore.createTask FAILED:', error)
      throw error
    }
  }

  async function updateTask(id: string, updates: Partial<Task> & { tag_ids?: string[] }) {
    const response = await api.updateTask(id, updates)
    const index = tasks.value.findIndex(t => t.id === id)
    if (index !== -1) {
      tasks.value[index] = response.data
    }
    invalidate('calendar:today')
    return response.data
  }

  async function deleteTask(id: string) {
    // Check if task has a trip before deleting (backend cascades trip deletion)
    const task = tasks.value.find(t => t.id === id)
    const tripId = task?.trip_id

    await api.deleteTask(id)
    tasks.value = tasks.value.filter(t => t.id !== id)
    invalidate('calendar:today')

    // If the task had a trip, clean up related stores since backend cascaded the deletion
    if (tripId) {
      // Remove trip from calendar trips list
      trips.value = trips.value.filter(t => t.id !== tripId)

      // Clean up receipts store
      const { useReceiptsStore } = await import('./receipts')
      const receiptsStore = useReceiptsStore()
      receiptsStore.trips = receiptsStore.trips.filter(t => t.id !== tripId)
      if (receiptsStore.currentTrip?.id === tripId) {
        receiptsStore.currentTrip = null
      }

      // Refresh inventory store so Purchases sheet item count stays in sync
      const { useInventoryStore } = await import('./inventory')
      const inventoryStore = useInventoryStore()
      if (inventoryStore.currentSheet) {
        inventoryStore.fetchSheet(inventoryStore.currentSheet.id)
      }
    }
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
    invalidate(`calendar:week:${format(weekStart.value, 'yyyy-MM-dd')}`)
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

  function removeTrip(tripId: string) {
    trips.value = trips.value.filter(t => t.id !== tripId)
  }

  function addTrip(trip: Trip) {
    // Add trip if not already present
    const exists = trips.value.some(t => t.id === trip.id)
    if (!exists) {
      trips.value.push(trip)
    }
  }

  function upsertTrip(trip: Trip) {
    const index = trips.value.findIndex(t => t.id === trip.id)
    if (index !== -1) {
      trips.value[index] = trip
    } else {
      trips.value.push(trip)
    }
  }

  function removePurchaseFromTrips(purchaseId: string) {
    for (const trip of trips.value) {
      if (trip.stops) {
        for (const stop of trip.stops) {
          if (stop.purchases) {
            stop.purchases = stop.purchases.filter(p => p.id !== purchaseId)
          }
        }
      }
    }
  }

  return {
    tasks,
    trips,
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
    tripsByDate,
    fetchTasks,
    fetchTripsForPeriod,
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
    filterTags,
    removeTrip,
    addTrip,
    upsertTrip,
    removePurchaseFromTrips
  }
})
