<script setup lang="ts">
import { ref, computed } from 'vue'
import { Clock, Trash, Edit, ListChecks, Loader2, CheckCircle2, Circle, PlayCircle } from 'lucide-vue-next'
import type { Task } from '@/types'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { useCalendarStore } from '@/stores/calendar'
import TaskForm from './TaskForm.vue'

interface Props {
  task: Task
  compact?: boolean // For month view cells
  dayIndex?: number // Day of week index (0-6), when provided emits edit event instead of showing modal
}

const props = withDefaults(defineProps<Props>(), {
  compact: false,
  dayIndex: undefined
})
const emit = defineEmits<{
  manageTrip: [tripId: string]
  edit: [task: Task] // Emitted when task should be edited (for weekly view cell-level popout)
}>()
const calendarStore = useCalendarStore()
const showEditForm = ref(false)
const isDeleting = ref(false)

// Compute accent color based on task priority or status
// Priority: 1 = high (most urgent), 2 = medium, 3+ = normal
const accentColor = computed(() => {
  if (props.task.status === 'completed') return 'bg-emerald-500'
  if (props.task.status === 'in_progress') return 'bg-amber-500'
  if (props.task.priority === 1) return 'bg-rose-500'
  if (props.task.priority === 2) return 'bg-orange-400'
  return 'bg-primary'
})

const statusIcon = computed(() => {
  if (props.task.status === 'completed') return CheckCircle2
  if (props.task.status === 'in_progress') return PlayCircle
  return Circle
})

const handleCardClick = () => {
  // In weekly view (dayIndex provided), emit event so CalendarView can render popout at cell level
  if (props.dayIndex !== undefined && !props.compact) {
    emit('edit', props.task)
  } else {
    showEditForm.value = true
  }
}

const toggleStatus = async () => {
  const nextStatus = props.task.status === 'completed' ? 'not_started' :
                     props.task.status === 'not_started' ? 'in_progress' : 'completed'
  await calendarStore.updateTask(props.task.id, { status: nextStatus })
}

const deleteTask = async () => {
  if (isDeleting.value) return
  isDeleting.value = true
  try {
    await calendarStore.deleteTask(props.task.id)
  } finally {
    isDeleting.value = false
  }
}
</script>

<template>
  <div>
    <!-- Compact version for month view cells -->
    <div 
      v-if="compact"
      :class="[
        'group relative flex items-center gap-1.5 px-1.5 py-1 rounded-md cursor-pointer transition-all duration-150',
        'hover:bg-white/5 hover:shadow-sm',
        task.status === 'completed' 
          ? 'opacity-60' 
          : ''
      ]"
      @click="showEditForm = true"
    >
      <!-- Accent dot -->
      <span :class="['w-1.5 h-1.5 rounded-full shrink-0', accentColor]" />
      
      <!-- Title -->
      <span :class="[
        'text-[11px] leading-tight truncate flex-1',
        task.status === 'completed' 
          ? 'line-through text-muted-foreground' 
          : 'text-foreground/90'
      ]">
        {{ task.title }}
      </span>
      
      <!-- Time badge (if has time) -->
      <span 
        v-if="task.start_time" 
        class="text-[9px] text-muted-foreground/70 tabular-nums shrink-0"
      >
        {{ task.start_time?.slice(0, 5) }}
      </span>
    </div>

    <!-- Full version for week view and expanded views -->
    <div 
      v-else
      :class="[
        'group relative overflow-hidden rounded-lg transition-all duration-200 cursor-pointer',
        'border border-white/[0.06] hover:border-white/[0.12]',
        'bg-gradient-to-br hover:shadow-lg hover:shadow-black/10',
        task.status === 'completed' 
          ? 'from-secondary/40 to-secondary/20 opacity-70' 
          : 'from-white/[0.04] to-transparent hover:from-white/[0.07]'
      ]"
      @click="handleCardClick"
    >
      <!-- Colored accent bar -->
      <div :class="['absolute left-0 top-0 bottom-0 w-[3px]', accentColor]" />
      
      <div class="pl-3 pr-2 py-2">
        <div class="flex items-start gap-2">
          <!-- Status icon button -->
          <button 
            :class="[
              'mt-0.5 shrink-0 transition-all duration-150',
              task.status === 'completed' 
                ? 'text-emerald-500' 
                : task.status === 'in_progress'
                  ? 'text-amber-500'
                  : 'text-muted-foreground/50 hover:text-primary'
            ]"
            @click.stop="toggleStatus"
          >
            <component :is="statusIcon" class="h-4 w-4" />
          </button>
          
          <div class="flex-1 min-w-0">
            <!-- Title -->
            <p :class="[
              'text-[13px] font-medium leading-snug',
              task.status === 'completed' 
                ? 'line-through text-muted-foreground' 
                : 'text-foreground'
            ]">
              {{ task.title }}
            </p>
            
            <!-- Meta row -->
            <div class="flex items-center gap-2 mt-1.5 flex-wrap">
              <!-- Time -->
              <span 
                v-if="task.start_time" 
                class="inline-flex items-center gap-1 text-[11px] text-muted-foreground/80 bg-white/[0.03] px-1.5 py-0.5 rounded"
              >
                <Clock class="h-3 w-3" />
                {{ task.start_time?.slice(0, 5) }}
              </span>
              
              <!-- Duration -->
              <span 
                v-if="task.duration_minutes" 
                class="text-[10px] text-muted-foreground/60 tabular-nums"
              >
                {{ task.duration_minutes }}min
              </span>
              
              <!-- Steps progress -->
              <span 
                v-if="task.steps.length > 0" 
                :class="[
                  'inline-flex items-center gap-1 text-[10px] px-1.5 py-0.5 rounded',
                  task.steps.filter(s => s.completed).length === task.steps.length
                    ? 'text-emerald-400 bg-emerald-500/10'
                    : 'text-muted-foreground/70 bg-white/[0.03]'
                ]"
              >
                <ListChecks class="h-3 w-3" />
                {{ task.steps.filter(s => s.completed).length }}/{{ task.steps.length }}
              </span>
            </div>
          </div>

          <!-- Actions (show on hover) -->
          <div class="flex items-center gap-0.5 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity duration-150">
            <Button 
              variant="ghost" 
              size="icon" 
              class="h-6 w-6 text-muted-foreground/60 hover:text-primary hover:bg-primary/10"
              @click.stop="handleCardClick"
              title="Edit task"
            >
              <Edit class="h-3 w-3" />
            </Button>
            <Button 
              variant="ghost" 
              size="icon" 
              class="h-6 w-6 text-muted-foreground/60 hover:text-destructive hover:bg-destructive/10"
              :disabled="isDeleting"
              @click.stop.prevent="deleteTask"
              title="Delete task"
            >
              <Loader2 v-if="isDeleting" class="h-3 w-3 animate-spin" />
              <Trash v-else class="h-3 w-3" />
            </Button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal Form for month view / mobile / compact -->
    <TaskForm
      v-if="showEditForm"
      :task="task"
      @close="showEditForm = false"
      @saved="showEditForm = false"
      @manage-trip="(tripId) => $emit('manageTrip', tripId)"
    />
  </div>
</template>


