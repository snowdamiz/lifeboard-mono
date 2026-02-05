<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { format } from 'date-fns'
import { X, Plus, Trash, GripVertical, MapPin } from 'lucide-vue-next'
import type { Task, TaskStep, Tag, Stop, Purchase } from '@/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { DateChooser } from '@/components/ui/date-chooser'
import { Checkbox } from '@/components/ui/checkbox'
import { Select } from '@/components/ui/select'
import { useCalendarStore } from '@/stores/calendar'
import { useReceiptsStore } from '@/stores/receipts'
import { useTagsStore } from '@/stores/tags'
import CollapsibleTagManager from '@/components/shared/CollapsibleTagManager.vue'
import PurchaseForm from '@/components/budget/PurchaseForm.vue'
import PurchaseList from '@/components/budget/PurchaseList.vue'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import { useTextTemplate } from '@/composables/useTextTemplate'

// Templates
const taskTitleTemplate = useTextTemplate('task_title')

interface Props {
  task?: Task
  initialDate?: Date | null
  manageTripAction?: (tripId: string) => void
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  saved: [task: Task]
  'manage-trip': [tripId: string]
}>()

const calendarStore = useCalendarStore()
const receiptsStore = useReceiptsStore()
const tagsStore = useTagsStore()
const saving = ref(false)

// Resolve tags from IDs
const resolvedTags = computed(() => {
  return Array.from(selectedTags.value)
    .map(id => tagsStore.tags.find((t: Tag) => t.id === id))
    .filter((t): t is Tag => t !== undefined)
})

// Form state - initialized by initForm
const form = ref({
  title: '',
  description: '',
  date: '',
  start_time: '',
  duration_minutes: 30,
  task_type: 'todo' as 'todo' | 'timed' | 'floating' | 'trip',
  status: 'not_started' as 'not_started' | 'in_progress' | 'completed'
})

const steps = ref<Array<{ id?: string; content: string; completed: boolean; isNew?: boolean }>>([])
const selectedTags = ref<Set<string>>(new Set())

const newStepContent = ref('')

// Track modal state for CollapsibleTagManager reset
const showModal = ref(true)

// Trip-specific state
const tripId = ref<string | null>(null)

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
    tripId.value = props.task.trip_id
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
    selectedTags.value = new Set()
    tripId.value = null
  }
  newStepContent.value = ''
}

onMounted(async () => {
    initForm()
    
    // Load tags from task if editing
    if (props.task && props.task.tags) {
        selectedTags.value = new Set(props.task.tags.map(t => t.id))
    }
    
    showModal.value = true
})

// Watch for task changes to reset showModal
watch(() => props.task, () => {
    showModal.value = false
    setTimeout(() => showModal.value = true, 50)
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

const onManageTripClick = async () => {
  // If no trip exists yet, create one first
  if (!tripId.value) {
    try {
      const trip = await receiptsStore.createTrip({
        driver: null,
        driver_id: null,
        trip_start: form.value.date ? `${form.value.date}T12:00:00Z` : new Date().toISOString(),
        trip_end: null,
        notes: null
      })
      tripId.value = trip.id
      
      // Update the task with the trip_id
      if (props.task) {
        await calendarStore.updateTask(props.task.id, { trip_id: trip.id })
      }
    } catch (e) {
      console.error('Failed to create trip', e)
      return
    }
  }
  
  // Close the task form first to avoid modal stacking
  emit('close')
  
  if (props.manageTripAction) {
    props.manageTripAction(tripId.value!)
  } else {
    emit('manage-trip', tripId.value!) 
  }
}


const save = async () => {
  // Auto-add pending step if exists
  if (newStepContent.value.trim()) {
    addStep()
  }

  if (!form.value.title.trim()) return
  
  // Save template
  taskTitleTemplate.save(form.value.title)

  if (saving.value) return
  saving.value = true
  
  try {
    console.log('Saving task...', { isEditing: isEditing.value, steps: steps.value })
    let savedTask: Task
    let createdTripId: string | null = null
    


    // If task type is trip and we don't have a trip yet, create one
    if (form.value.task_type === 'trip' && !tripId.value) {
      // Always set trip_start to task's date (at midnight local if no time specified)
      let tripStart: string
      if (form.value.date) {
        if (form.value.start_time) {
          tripStart = `${form.value.date}T${form.value.start_time}:00Z`
        } else {
          // Create midnight local time, adjusted for timezone offset
          const date = new Date(`${form.value.date}T12:00:00`)
          const userTimezoneOffset = date.getTimezoneOffset() * 60000
          const adjustedDate = new Date(date.getTime() + userTimezoneOffset)
          tripStart = adjustedDate.toISOString()
        }
      } else {
        // No date set, use current time
        tripStart = new Date().toISOString()
      }
      
      const trip = await receiptsStore.createTrip({
        driver: null, // Legacy field
        driver_id: null,
        trip_start: tripStart,
        trip_end: null,
        notes: null
      })
      createdTripId = trip.id
      tripId.value = trip.id
    }
    
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
      tag_ids: Array.from(selectedTags.value),
      steps: taskSteps as unknown as TaskStep[],
      trip_id: createdTripId || tripId.value || undefined
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

    // If trip was created, open detail modal BEFORE closing form to ensure event is handled
    if (form.value.task_type === 'trip' && createdTripId) {
      emit('manage-trip', createdTripId)
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
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4" data-testid="modal-backdrop" @click.self="emit('close')">
      <div class="w-full sm:max-w-lg bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[95vh] sm:max-h-[92vh] flex flex-col" role="dialog">
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
            <SearchableInput 
                v-model="form.title" 
                placeholder="Task title" 
                class="mt-1.5"
                data-testid="title-input"
                :search-function="taskTitleTemplate.search"
                :show-create-option="true"
                :min-chars="0"
                @create="(val) => form.title = val"
            />
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
              <DateChooser v-model="form.date" class="mt-1.5" />
            </div>
            <div>
              <label class="text-sm font-medium">Type</label>
              <Select
                v-model="form.task_type"
                :options="[
                  { value: 'todo', label: 'To Do' },
                  { value: 'timed', label: 'Timed' },
                  { value: 'floating', label: 'Floating' },
                  { value: 'trip', label: 'Trip' }
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

          <!-- Trip-specific fields -->
          <div v-if="form.task_type === 'trip'" class="pt-2">
            <Button 
              type="button" 
              variant="outline" 
              class="w-full" 
              @click="onManageTripClick"
            >
              <MapPin class="h-4 w-4 mr-2" />
              Manage Trip Details
            </Button>
          </div>

          <!-- Steps and Tags in 2 columns -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <!-- Tags -->
            <div>
              <CollapsibleTagManager
                :applied-tag-ids="selectedTags"
                :tags="resolvedTags"
                :reset-trigger="!showModal"
                @add-tags="(tags) => tags.forEach(id => selectedTags.add(id))"
                @remove-tag="(id) => selectedTags.delete(id)"
              />
            </div>

            <!-- Steps -->
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
          </div>
        </form>

        <!-- Fixed Footer -->
        <div class="flex gap-3 p-4 border-t border-border bg-card shrink-0">
          <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="emit('close')">
            Cancel
          </Button>
          <Button type="submit" class="flex-1 sm:flex-none sm:ml-auto" :disabled="saving || !form.title.trim()" @click="save" data-testid="submit-button">
            {{ saving ? 'Saving...' : (isEditing ? 'Save Changes' : 'Create') }}
          </Button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

