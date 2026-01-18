<script setup lang="ts">
import { ref } from 'vue'
import { Clock, Trash, Edit, ListChecks, Loader2 } from 'lucide-vue-next'
import type { Task } from '@/types'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { useCalendarStore } from '@/stores/calendar'
import TaskForm from './TaskForm.vue'

interface Props {
  task: Task
}

const props = defineProps<Props>()
const calendarStore = useCalendarStore()
const showEditForm = ref(false)
const isDeleting = ref(false)

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
    <div 
      :class="[
        'group p-2.5 rounded-lg border bg-card transition-all cursor-pointer',
        task.status === 'completed' 
          ? 'border-border/50 bg-secondary/30' 
          : 'border-border hover:border-primary/30 hover:shadow-sm'
      ]"
      @click="showEditForm = true"
    >
      <div class="flex items-start gap-2">
        <Checkbox 
          :model-value="task.status === 'completed'"
          class="mt-0.5 shrink-0"
          @click.stop
          @update:model-value="toggleStatus"
        />
        
        <div class="flex-1 min-w-0">
          <p :class="[
            'text-[13px] font-medium leading-snug',
            task.status === 'completed' && 'line-through text-muted-foreground'
          ]">
            {{ task.title }}
          </p>
          
          <div class="flex items-center gap-1.5 mt-1.5 flex-wrap">
            <span v-if="task.start_time" class="text-[11px] text-muted-foreground flex items-center gap-1">
              <Clock class="h-3 w-3" />
              {{ task.start_time?.slice(0, 5) }}
            </span>
            <Badge v-if="task.duration_minutes" variant="outline" class="text-[10px] px-1.5 h-4">
              {{ task.duration_minutes }}m
            </Badge>
            <span v-if="task.steps.length > 0" class="text-[10px] text-muted-foreground flex items-center gap-0.5">
              <ListChecks class="h-3 w-3" />
              {{ task.steps.filter(s => s.completed).length }}/{{ task.steps.length }}
            </span>
          </div>
        </div>

        <div class="flex items-center gap-0.5 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
          <Button 
            variant="ghost" 
            size="icon" 
            class="h-6 w-6 text-muted-foreground hover:text-primary"
            @click.stop="showEditForm = true"
            title="Edit task"
          >
            <Edit class="h-3 w-3" />
          </Button>
          <Button 
            variant="ghost" 
            size="icon" 
            class="h-6 w-6 text-muted-foreground hover:text-destructive"
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

    <TaskForm
      v-if="showEditForm"
      :task="task"
      @close="showEditForm = false"
      @saved="showEditForm = false"
    />
  </div>
</template>
