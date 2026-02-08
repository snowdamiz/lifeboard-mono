<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue'
import { format } from 'date-fns'
import { X, Plus, Trash, MapPin, Clock, Calendar, ListChecks, Tag as TagIcon } from 'lucide-vue-next'
import type { Task, TaskStep, Tag } from '@/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { DateChooser } from '@/components/ui/date-chooser'
import { Checkbox } from '@/components/ui/checkbox'
import { Select } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { useCalendarStore } from '@/stores/calendar'
import { useReceiptsStore } from '@/stores/receipts'
import { useTagsStore } from '@/stores/tags'
import CollapsibleTagManager from '@/components/shared/CollapsibleTagManager.vue'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import { useTextTemplate } from '@/composables/useTextTemplate'

const taskTitleTemplate = useTextTemplate('task_title')

interface Props {
  task?: Task | null
  dayIndex: number // 0-6, used to determine popout direction
  initialDate?: Date | null // For creating new tasks
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
const popoutRef = ref<HTMLElement | null>(null)

// Popout direction: right for left-side days (0-4), left for right-side days (5-6)
const popoutDirection = computed(() => props.dayIndex >= 5 ? 'left' : 'right')

// Resolve tags from IDs
const resolvedTags = computed(() => {
  return Array.from(selectedTags.value)
    .map(id => tagsStore.tags.find((t: Tag) => t.id === id))
    .filter((t): t is Tag => t !== undefined)
})

// Form state
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
const tripId = ref<string | null>(null)
const showModal = ref(true)

const isEditing = computed(() => !!props.task?.id)

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
    steps.value = props.task.steps?.map(s => ({ ...s })) || []
    tripId.value = props.task.trip_id
    
    if (props.task.tags) {
      selectedTags.value = new Set(props.task.tags.map(t => t.id))
    }
  } else {
    // Create mode
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
    tripId.value = null
    selectedTags.value = new Set()
  }
}

onMounted(() => {
  initForm()
  showModal.value = true
  
  // Close on outside click
  document.addEventListener('click', handleOutsideClick)
})

// Reinitialize form when task or initialDate changes (for switching between edit/create modes)
watch(() => [props.task, props.initialDate], () => {
  initForm()
}, { immediate: false })

onUnmounted(() => {
  document.removeEventListener('click', handleOutsideClick)
})

const handleOutsideClick = (e: MouseEvent) => {
  if (popoutRef.value && !popoutRef.value.contains(e.target as Node)) {
    emit('close')
  }
}

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
  if (!tripId.value) {
    try {
      const trip = await receiptsStore.createTrip({
        driver: null,
        driver_id: null,
        trip_start: form.value.date ? `${form.value.date}T12:00:00` : null,
        trip_end: null,
        notes: null
      })
      tripId.value = trip.id
      
      if (props.task?.id) {
        await calendarStore.updateTask(props.task.id, { trip_id: trip.id })
      }
    } catch (e) {
      console.error('Failed to create trip', e)
      return
    }
  }
  
  emit('manage-trip', tripId.value!)
}

const save = async () => {
  if (newStepContent.value.trim()) {
    addStep()
  }

  if (!form.value.title.trim()) return
  
  taskTitleTemplate.save(form.value.title)

  if (saving.value) return
  saving.value = true
  
  try {
    let createdTripId: string | null = null

    if (form.value.task_type === 'trip' && !tripId.value) {
      let tripStart = null
      if (form.value.date) {
        if (form.value.start_time) {
          tripStart = `${form.value.date}T${form.value.start_time}:00`
        } else {
          const date = new Date(`${form.value.date}T12:00:00`)
          const userTimezoneOffset = date.getTimezoneOffset() * 60000
          const adjustedDate = new Date(date.getTime() + userTimezoneOffset)
          tripStart = adjustedDate.toISOString()
        }
      }
      
      const trip = await receiptsStore.createTrip({
        driver: null,
        driver_id: null,
        trip_start: tripStart,
        trip_end: null,
        notes: null
      })
      createdTripId = trip.id
      tripId.value = trip.id
    }
    
    const taskSteps = steps.value.map((step, index) => ({
      ...step,
      position: index,
      isNew: undefined
    }))

    const taskPayload = {
      ...form.value,
      duration_minutes: (form.value.task_type === 'timed' || form.value.task_type === 'floating') ? form.value.duration_minutes : null,
      start_time: form.value.task_type === 'timed' ? form.value.start_time : null,
      tag_ids: Array.from(selectedTags.value),
      steps: taskSteps as unknown as TaskStep[],
      trip_id: createdTripId || tripId.value || null
    }

    const savedTask = isEditing.value && props.task?.id
      ? await calendarStore.updateTask(props.task.id, taskPayload)
      : await calendarStore.createTask(taskPayload)

    if (form.value.task_type === 'trip' && createdTripId) {
      emit('manage-trip', createdTripId)
    }

    emit('saved', savedTask)
  } catch (e) {
    console.error('Failed to save task:', e)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div 
    ref="popoutRef"
    data-testid="task-detail-popout"
    class="h-full bg-card border border-white/[0.12] rounded-xl shadow-2xl overflow-hidden flex flex-col"
    @click.stop
  >
    <!-- Header -->
    <div class="flex items-center justify-between px-4 py-3 border-b border-white/[0.08] bg-gradient-to-r from-white/[0.04] to-transparent shrink-0">
      <h3 class="text-sm font-semibold">{{ isEditing ? 'Edit Task' : 'New Task' }}</h3>
      <Button variant="ghost" size="icon" class="h-7 w-7" @click="emit('close')">
        <X class="h-4 w-4" />
      </Button>
    </div>

    <!-- Content - Multi-column layout with description at bottom -->
    <div class="flex-1 p-4 overflow-hidden flex flex-col">
      <!-- Top section: 3-column grid -->
      <div class="grid grid-cols-3 gap-6 shrink-0">
        <!-- Left Column: Title, Date/Type/Trip -->
        <div class="space-y-3">
          <div>
            <label class="text-xs font-medium text-muted-foreground">Title</label>
            <SearchableInput 
              v-model="form.title" 
              placeholder="Task title" 
              class="mt-1.5"
              :search-function="taskTitleTemplate.search"
              :show-create-option="true"
              :min-chars="0"
              @create="(val) => form.title = val"
            />
          </div>

          <!-- Date & Type -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-xs font-medium text-muted-foreground">Date</label>
              <DateChooser v-model="form.date" class="mt-1.5" />
            </div>
            <div>
              <label class="text-xs font-medium text-muted-foreground">Type</label>
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

          <!-- Time & Duration (conditional) -->
          <div v-if="form.task_type === 'timed' || form.task_type === 'floating'" class="grid grid-cols-2 gap-3">
            <div v-if="form.task_type === 'timed'">
              <label class="text-xs font-medium text-muted-foreground">Start Time</label>
              <Input v-model="form.start_time" type="time" class="mt-1.5" />
            </div>
            <div>
              <label class="text-xs font-medium text-muted-foreground">Duration (min)</label>
              <Input v-model.number="form.duration_minutes" type="number" min="5" step="5" class="mt-1.5" />
            </div>
          </div>

          <!-- Trip management -->
          <div v-if="form.task_type === 'trip'">
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
        </div>

        <!-- Middle Column: Tags -->
        <div>
          <CollapsibleTagManager
            :applied-tag-ids="selectedTags"
            :tags="resolvedTags"
            :reset-trigger="!showModal"
            @add-tags="(tags) => tags.forEach(id => selectedTags.add(id))"
            @remove-tag="(id) => selectedTags.delete(id)"
          />
        </div>

        <!-- Right Column: Steps -->
        <div class="flex flex-col max-h-[200px]">
          <label class="text-xs font-medium text-muted-foreground mb-2">Steps</label>
          <div class="flex-1 space-y-2 overflow-y-auto pr-1">
            <div
              v-for="(step, index) in steps"
              :key="step.id || index"
              class="flex items-center gap-2 p-2 bg-secondary/40 rounded-lg"
            >
              <Checkbox v-model="step.completed" class="shrink-0" />
              <Input v-model="step.content" class="flex-1 h-8 bg-transparent border-0 focus-visible:ring-0" />
              <Button variant="ghost" size="icon" type="button" class="h-7 w-7 shrink-0" @click="removeStep(index)">
                <Trash class="h-3.5 w-3.5 text-destructive" />
              </Button>
            </div>

            <div class="flex items-center gap-2">
              <Plus class="h-4 w-4 text-muted-foreground shrink-0" />
              <Input 
                v-model="newStepContent" 
                placeholder="Add a step..."
                class="flex-1 h-8"
                @keydown.enter.prevent="addStep"
              />
              <Button variant="outline" size="sm" type="button" class="shrink-0" @click="addStep">
                Add
              </Button>
            </div>
          </div>
        </div>
      </div>

      <!-- Bottom section: Description (full width) -->
      <div class="mt-4 flex-1 min-h-0">
        <label class="text-xs font-medium text-muted-foreground">Description</label>
        <textarea
          v-model="form.description"
          placeholder="Optional description..."
          class="mt-1.5 w-full h-[calc(100%-24px)] rounded-lg border border-input bg-transparent px-3 py-2 text-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring/50 resize-none"
        />
      </div>
    </div>

    <!-- Footer -->
    <div class="flex justify-end gap-3 px-4 py-3 border-t border-white/[0.08] bg-gradient-to-r from-transparent to-white/[0.02] shrink-0">
      <Button variant="outline" type="button" @click="emit('close')">
        Cancel
      </Button>
      <Button :disabled="saving || !form.title.trim()" @click="save">
        {{ saving ? 'Saving...' : (isEditing ? 'Save Changes' : 'Create Task') }}
      </Button>
    </div>
  </div>
</template>
