<script setup lang="ts">
import { ref } from 'vue'
import { Clock, MoreVertical, Trash, Edit, ListChecks } from 'lucide-vue-next'
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
const showMenu = ref(false)
const showEditForm = ref(false)

const toggleStatus = async () => {
  const nextStatus = props.task.status === 'completed' ? 'not_started' :
                     props.task.status === 'not_started' ? 'in_progress' : 'completed'
  await calendarStore.updateTask(props.task.id, { status: nextStatus })
}

const deleteTask = async () => {
  if (confirm('Delete this task?')) {
    await calendarStore.deleteTask(props.task.id)
  }
}
</script>

<template>
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

      <div class="relative shrink-0">
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-6 w-6 opacity-0 group-hover:opacity-100 transition-opacity"
          @click.stop="showMenu = !showMenu"
        >
          <MoreVertical class="h-3.5 w-3.5" />
        </Button>

        <Transition
          enter-active-class="transition duration-100 ease-out"
          enter-from-class="opacity-0 scale-95"
          enter-to-class="opacity-100 scale-100"
          leave-active-class="transition duration-75 ease-in"
          leave-from-class="opacity-100 scale-100"
          leave-to-class="opacity-0 scale-95"
        >
          <div 
            v-if="showMenu"
            class="absolute right-0 top-full mt-1 w-28 origin-top-right bg-card border border-border/80 rounded-lg shadow-lg py-1 z-10"
          >
            <button 
              class="w-full flex items-center gap-2 px-3 py-1.5 text-[13px] hover:bg-secondary transition-colors"
              @click.stop="showEditForm = true; showMenu = false"
            >
              <Edit class="h-3.5 w-3.5" />
              Edit
            </button>
            <button 
              class="w-full flex items-center gap-2 px-3 py-1.5 text-[13px] text-destructive hover:bg-destructive/10 transition-colors"
              @click.stop="deleteTask"
            >
              <Trash class="h-3.5 w-3.5" />
              Delete
            </button>
          </div>
        </Transition>
      </div>
    </div>
  </div>

  <TaskForm
    v-if="showEditForm"
    :task="task"
    @close="showEditForm = false"
    @saved="showEditForm = false"
  />
</template>
