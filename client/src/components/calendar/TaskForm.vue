<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { format } from 'date-fns'
import { X, Plus, Trash, GripVertical } from 'lucide-vue-next'
import type { Task, TaskStep, Tag } from '@/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Checkbox } from '@/components/ui/checkbox'
import { Select } from '@/components/ui/select'
import { useCalendarStore } from '@/stores/calendar'
import TagSelector from '@/components/shared/TagSelector.vue'

interface Props {
  task?: Task
  initialDate?: Date | null
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  saved: [task: Task]
}>()

const calendarStore = useCalendarStore()
const saving = ref(false)

// Form state - initialized by initForm
const form = ref({
  title: '',
  description: '',
  date: '',
  start_time: '',
  duration_minutes: 30,
  task_type: 'todo' as 'todo' | 'timed' | 'floating',
  status: 'not_started' as 'not_started' | 'in_progress' | 'completed'
})

const steps = ref<Array<{ id?: string; content: string; completed: boolean; isNew?: boolean }>>([])
const selectedTags = ref<Tag[]>([])

const newStepContent = ref('')

const isEditing = computed(() => !!props.task)

// Initialize form with task data or fresh values
const initForm = () => {
  if (props.task) {
    form.value = {
      title: props.task.title || '',
      description: props.task.description || '',
      date: props.task.date || '',
      start_time: props.task.start_time || '',
      duration_minutes: props.task.duration_minutes || 30,
      task_type: props.task.task_type || 'todo',
      status: props.task.status || 'not_started'
    }
    steps.value = props.task.steps.map(s => ({ ...s }))
  } else {
    // Fresh form for new task
    form.value = {
      title: '',
      description: '',
      date: props.initialDate ? format(props.initialDate, 'yyyy-MM-dd') : '',
      start_time: '',
      duration_minutes: 30,
      task_type: 'todo',
      status: 'not_started'
    }
    steps.value = []
    selectedTags.value = []
  }
  newStepContent.value = ''
}

// Initialize on mount
onMounted(() => {
  initForm()
  // Load tags from task if editing
  if (props.task && props.task.tags) {
    selectedTags.value = [...props.task.tags]
  }
})

const addStep = () => {
  if (!newStepContent.value.trim()) return
  steps.value.push({
    content: newStepContent.value,
    completed: false,
    isNew: true
  })
  newStepContent.value = ''
}

const removeStep = (index: number) => {
  steps.value.splice(index, 1)
}

const save = async () => {
  // Auto-add pending step if exists
  if (newStepContent.value.trim()) {
    addStep()
  }

  if (!form.value.title.trim()) return
  
  if (saving.value) return
  saving.value = true
  
  try {
    console.log('Saving task...', { isEditing: isEditing.value, steps: steps.value })
    let savedTask: Task
    
    // Prepare steps with positions
    const taskSteps = steps.value.map((step, index) => ({
      ...step,
      position: index,
      isNew: undefined // Remove helper prop
    }))

    const taskPayload = {
      ...form.value,
      duration_minutes: (form.value.task_type === 'timed' || form.value.task_type === 'floating') ? form.value.duration_minutes : null,
      start_time: form.value.task_type === 'timed' ? form.value.start_time : null,
      tag_ids: selectedTags.value.map(t => t.id),
      steps: taskSteps as unknown as TaskStep[]
    }

    if (isEditing.value) {
      // Backend handles nested update/delete via cast_assoc + on_replace: :delete
      // Note: we must include existing steps with their IDs to update them, 
      // and new steps without IDs to create them.
      // Missing IDs will be deleted by backend.
      savedTask = await calendarStore.updateTask(props.task!.id, taskPayload)
    } else {
      savedTask = await calendarStore.createTask(taskPayload)
    }

    emit('saved', savedTask)
  } catch (e) {
    console.error('Failed to save task:', e)
    // Here we could add a toast notification
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="w-full sm:max-w-lg bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[95vh] sm:max-h-[92vh] flex flex-col">
        <!-- Header -->
        <div class="flex items-center justify-between p-4 border-b border-border shrink-0">
          <h2 class="text-lg font-semibold">
            {{ isEditing ? 'Edit Task' : 'New Task' }}
          </h2>
          <Button variant="ghost" size="icon" @click="emit('close')">
            <X class="h-4 w-4" />
          </Button>
        </div>

        <!-- Scrollable Form Content -->
        <form class="flex-1 overflow-auto p-4 space-y-4" @submit.prevent="save">
          <div>
            <label class="text-sm font-medium">Title</label>
            <Input v-model="form.title" placeholder="Task title" class="mt-1.5" />
          </div>

          <div>
            <label class="text-sm font-medium">Description</label>
            <textarea
              v-model="form.description"
              placeholder="Optional description..."
              class="mt-1.5 w-full rounded-lg border border-input bg-transparent px-3 py-2.5 text-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50 min-h-[70px] resize-none"
            />
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm font-medium">Date</label>
              <Input v-model="form.date" type="date" class="mt-1.5" />
            </div>
            <div>
              <label class="text-sm font-medium">Type</label>
              <Select
                v-model="form.task_type"
                :options="[
                  { value: 'todo', label: 'To Do' },
                  { value: 'timed', label: 'Timed' },
                  { value: 'floating', label: 'Floating' }
                ]"
                placeholder="Select type"
                class="mt-1.5"
              />
            </div>
          </div>

          <div v-if="form.task_type === 'timed' || form.task_type === 'floating'" class="grid grid-cols-2 gap-3">
            <div v-if="form.task_type === 'timed'">
              <label class="text-sm font-medium">Start Time</label>
              <Input v-model="form.start_time" type="time" class="mt-1.5" />
            </div>
            <div class="">
              <label class="text-sm font-medium">Duration (min)</label>
              <Input v-model.number="form.duration_minutes" type="number" min="5" step="5" class="mt-1.5" />
            </div>
          </div>

          <div>
            <label class="text-sm font-medium">Tags</label>
            <TagSelector 
              v-model="selectedTags" 
              placeholder="Add tags..." 
              class="mt-1.5" 
              @tags-deleted="calendarStore.fetchWeekTasks()"
            />
          </div>

          <div>
            <label class="text-sm font-medium">Steps</label>
            <div class="mt-2 space-y-2">
              <div
                v-for="(step, index) in steps"
                :key="step.id || index"
                class="flex items-center gap-2 p-2 bg-secondary/40 rounded-lg"
              >
                <Checkbox v-model="step.completed" class="shrink-0" />
                <Input v-model="step.content" class="flex-1 h-8 bg-transparent border-0 focus-visible:ring-0 px-1" />
                <Button variant="ghost" size="icon" type="button" class="h-7 w-7 shrink-0" @click="removeStep(index)">
                  <Trash class="h-3.5 w-3.5 text-destructive" />
                </Button>
              </div>

              <div class="flex items-center gap-2">
                <Plus class="h-4 w-4 text-muted-foreground shrink-0" />
                <Input 
                  v-model="newStepContent" 
                  placeholder="Add a step..."
                  class="flex-1 h-9"
                  @keydown.enter.prevent="addStep"
                />
                <Button variant="outline" size="sm" type="button" class="shrink-0" @click="addStep">
                  Add
                </Button>
              </div>
            </div>
          </div>
        </form>

        <!-- Fixed Footer -->
        <div class="flex gap-3 p-4 border-t border-border bg-card shrink-0">
          <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="emit('close')">
            Cancel
          </Button>
          <Button type="submit" class="flex-1 sm:flex-none sm:ml-auto" :disabled="saving || !form.title.trim()" @click="save">
            {{ saving ? 'Saving...' : (isEditing ? 'Update' : 'Create') }}
          </Button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

