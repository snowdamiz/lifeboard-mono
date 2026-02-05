<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import { format, parseISO } from 'date-fns'
import { Plus, Clock, CheckSquare } from 'lucide-vue-next'
import type { Task } from '@/types'
import { Button } from '@/components/ui/button'
import { useCalendarStore } from '@/stores/calendar'
import { useTabs } from '@/composables/useTabs'
import TaskCard from '@/components/calendar/TaskCard.vue'
import TaskForm from '@/components/calendar/TaskForm.vue'
import TripDetailModal from '@/components/calendar/TripDetailModal.vue'

// Trip detail modal
const showTripDetailModal = ref(false)
const selectedTripId = ref<string | null>(null)

const handleOpenTripDetail = (tripId: string) => {
  selectedTripId.value = tripId
  showTripDetailModal.value = true
  
  // Close task form with slight delay
  setTimeout(() => {
    showTaskForm.value = false
  }, 10)
}

const closeTripDetailModal = () => {
  showTripDetailModal.value = false
  selectedTripId.value = null
}

const route = useRoute()
const calendarStore = useCalendarStore()
const showTaskForm = ref(false)
const selectedTask = ref<Task | null>(null)

// Tab state using composable
const { activeTab, setTab } = useTabs<'schedule' | 'todos'>({
  tabs: [
    { key: 'schedule', label: 'Schedule' },
    { key: 'todos', label: 'To Do' }
  ],
  defaultTab: 'schedule'
})

const currentDate = computed(() => {
  const dateParam = route.params.date as string
  return dateParam ? parseISO(dateParam) : new Date()
})

const dayTasks = computed(() => {
  const dateKey = format(currentDate.value, 'yyyy-MM-dd')
  return calendarStore.tasksByDate[dateKey] || []
})

const timedTasks = computed(() => 
  dayTasks.value.filter(t => t.task_type === 'timed' && t.start_time)
)

const todoTasks = computed(() => 
  dayTasks.value.filter(t => t.task_type === 'todo' || !t.start_time)
)

const hours = Array.from({ length: 24 }, (_, i) => i)

const openNewTask = () => {
  selectedTask.value = null
  showTaskForm.value = true
}

const openEditTask = (task: Task) => {
  selectedTask.value = task
  showTaskForm.value = true
}

const onTaskSaved = async () => {
  showTaskForm.value = false
  selectedTask.value = null
  // Refetch to ensure everything is in sync
  await calendarStore.fetchCurrentViewTasks()
}

const onFormClose = () => {
  showTaskForm.value = false
  selectedTask.value = null
}

onMounted(() => {
  calendarStore.fetchTasks(currentDate.value, currentDate.value)
})
</script>

<template>
  <div class="h-full flex flex-col animate-fade-in">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4 sm:mb-6">
      <div>
        <h1 class="text-2xl sm:text-3xl font-bold">{{ format(currentDate, 'EEEE') }}</h1>
        <p class="text-muted-foreground text-sm sm:text-base">{{ format(currentDate, 'MMMM d, yyyy') }}</p>
      </div>

      <Button @click="openNewTask" class="w-full sm:w-auto">
        <Plus class="h-4 w-4 mr-2" />
        New Task
      </Button>
    </div>

    <!-- Mobile: Tab Navigation -->
    <div class="flex gap-1 p-1 bg-secondary/50 rounded-lg mb-4 md:hidden">
      <button
        :class="[
          'flex-1 px-3 py-2 text-sm font-medium rounded-md transition-colors',
          activeTab === 'schedule' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground'
        ]"
        @click="activeTab = 'schedule'"
      >
        <Clock class="h-4 w-4 inline mr-1.5" />
        Schedule
      </button>
      <button
        :class="[
          'flex-1 px-3 py-2 text-sm font-medium rounded-md transition-colors',
          activeTab === 'todos' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground'
        ]"
        @click="activeTab = 'todos'"
      >
        <CheckSquare class="h-4 w-4 inline mr-1.5" />
        To Do ({{ todoTasks.length }})
      </button>
    </div>

    <!-- Desktop: Grid Layout / Mobile: Tabbed Content -->
    <div class="flex-1 overflow-hidden">
      <!-- Desktop view -->
      <div class="hidden md:grid grid-cols-3 gap-6 h-full">
        <!-- Time-based tasks -->
        <div class="col-span-2 overflow-auto border border-border rounded-xl bg-card">
          <div class="relative">
            <div
              v-for="hour in hours"
              :key="hour"
              class="flex border-b border-border last:border-0"
            >
              <div class="w-16 p-2 text-xs text-muted-foreground text-right border-r border-border">
                {{ hour.toString().padStart(2, '0') }}:00
              </div>
              <div class="flex-1 h-16 relative">
                <!-- Render timed tasks here -->
              </div>
            </div>

            <!-- Overlay timed tasks -->
            <div
              v-for="task in timedTasks"
              :key="task.id"
              class="absolute left-16 right-0 mx-2 cursor-pointer hover:brightness-95 transition-all group"
              @click="openEditTask(task)"
              :style="{
                top: `${(parseInt(task.start_time!.split(':')[0]) * 64) + (parseInt(task.start_time!.split(':')[1]) / 60 * 64)}px`,
                height: `${(task.duration_minutes || 30) / 60 * 64}px`
              }"
            >
              <div class="h-full bg-primary/20 border-l-4 border-primary rounded-r-lg p-2">
                <p class="text-sm font-medium truncate">{{ task.title }}</p>
                <p class="text-xs text-muted-foreground">
                  <Clock class="h-3 w-3 inline mr-1" />
                  {{ task.duration_minutes }}min
                  <span v-if="task.steps?.length" class="ml-1 opacity-75">
                    • {{ task.steps.filter(s => s.completed).length }}/{{ task.steps.length }}
                  </span>
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- Todo list -->
        <div class="overflow-auto border border-border rounded-xl bg-card p-4">
          <h2 class="text-lg font-semibold mb-4">To Do</h2>
          
          <div class="space-y-2">
            <TaskCard
              v-for="task in todoTasks"
              :key="task.id"
              :task="task"
              @manage-trip="handleOpenTripDetail"
            />

            <div v-if="todoTasks.length === 0" class="text-center py-8 text-muted-foreground">
              <p>No tasks for this day</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Mobile view: Schedule Tab -->
      <div v-if="activeTab === 'schedule'" class="md:hidden h-full overflow-auto border border-border rounded-xl bg-card">
        <div class="relative">
          <div
            v-for="hour in hours"
            :key="hour"
            class="flex border-b border-border last:border-0"
          >
            <div class="w-14 p-2 text-xs text-muted-foreground text-right border-r border-border shrink-0">
              {{ hour.toString().padStart(2, '0') }}:00
            </div>
            <div class="flex-1 h-14 relative">
              <!-- Render timed tasks here -->
            </div>
          </div>

          <!-- Overlay timed tasks - Mobile -->
          <div
            v-for="task in timedTasks"
            :key="task.id"
            class="absolute left-14 right-0 mx-1.5 cursor-pointer hover:brightness-95 transition-all group"
            @click="openEditTask(task)"
            :style="{
              top: `${(parseInt(task.start_time!.split(':')[0]) * 56) + (parseInt(task.start_time!.split(':')[1]) / 60 * 56)}px`,
              height: `${Math.max((task.duration_minutes || 30) / 60 * 56, 28)}px`
            }"
          >
            <div class="h-full bg-primary/20 border-l-3 border-primary rounded-r-lg px-2 py-1">
              <div class="flex items-center justify-between gap-1">
                <p class="text-xs font-medium truncate">{{ task.title }}</p>
                <span v-if="task.steps?.length" class="text-[10px] text-muted-foreground shrink-0">
                  {{ task.steps.filter(s => s.completed).length }}/{{ task.steps.length }}
                </span>
              </div>
              <p class="text-[10px] text-muted-foreground">{{ task.duration_minutes }}min</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Mobile view: Todos Tab -->
      <div v-if="activeTab === 'todos'" class="md:hidden h-full overflow-auto space-y-2">
        <TaskCard
          v-for="task in todoTasks"
          :key="task.id"
          :task="task"
          class="!p-3"
          @manage-trip="handleOpenTripDetail"
        />

        <div v-if="todoTasks.length === 0" class="text-center py-12 text-muted-foreground">
          <CheckSquare class="h-8 w-8 mx-auto mb-3 opacity-40" />
          <p class="text-sm">No to-do tasks</p>
          <Button size="sm" variant="outline" class="mt-3" @click="openNewTask">
            <Plus class="h-4 w-4 mr-1" />
            Add Task
          </Button>
        </div>
      </div>
    </div>

    <TaskForm
      v-if="showTaskForm"
      :task="selectedTask || undefined"
      :initial-date="currentDate"
      @close="onFormClose"
      @saved="onTaskSaved"
      :manage-trip-action="handleOpenTripDetail"
      @manage-trip="handleOpenTripDetail"
    />

    <TripDetailModal
      v-if="showTripDetailModal && selectedTripId"
      :trip-id="selectedTripId"
      @close="closeTripDetailModal"
    />
  </div>
</template>

