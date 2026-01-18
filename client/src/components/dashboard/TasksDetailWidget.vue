<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { ChevronRight, Clock, Sparkles } from 'lucide-vue-next'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { useCalendarStore } from '@/stores/calendar'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()
const calendarStore = useCalendarStore()

const todaysTasks = computed(() => calendarStore.todaysTasks)
</script>

<template>
  <div class="h-full flex flex-col">
    <CardHeader class="flex flex-row items-center justify-between pb-2 sm:pb-3 p-3 sm:p-4">
      <CardTitle class="text-sm sm:text-base font-medium">Today's Tasks</CardTitle>
      <Button 
        variant="ghost" 
        size="sm" 
        class="text-muted-foreground hover:text-foreground -mr-2 h-8 px-2 sm:px-3" 
        @click="!isEditMode && router.push('/calendar')"
      >
        <span class="hidden sm:inline">View all</span>
        <ChevronRight class="h-4 w-4 sm:ml-0.5" />
      </Button>
    </CardHeader>
    <CardContent class="pt-0 p-3 sm:p-4 sm:pt-0 flex-1 overflow-auto">
      <div v-if="todaysTasks.length === 0" class="text-center py-4">
        <div class="h-10 w-10 rounded-xl bg-primary/5 mx-auto mb-2 flex items-center justify-center">
          <Sparkles class="h-5 w-5 text-primary/60" />
        </div>
        <p class="font-medium text-foreground text-sm">No tasks scheduled</p>
        <p class="text-xs text-muted-foreground mt-0.5">Enjoy your free day!</p>
        <Button variant="outline" size="sm" class="mt-2 h-7 text-xs" @click="!isEditMode && router.push('/calendar')">
          Add a task
        </Button>
      </div>
      <div v-else class="space-y-1">
        <div
          v-for="task in todaysTasks.slice(0, 5)"
          :key="task.id"
          class="flex items-center gap-2.5 sm:gap-3 p-2.5 sm:p-3 rounded-lg hover:bg-secondary/60 active:bg-secondary transition-colors cursor-pointer touch-manipulation"
          @click="!isEditMode && router.push(`/calendar?date=${task.scheduled_date}`)"
        >
          <div 
            :class="[
              'status-dot shrink-0',
              task.status === 'completed' ? 'status-completed' :
              task.status === 'in_progress' ? 'status-in-progress' : 'status-not-started'
            ]"
          />
          <div class="flex-1 min-w-0">
            <p :class="['text-xs sm:text-sm font-medium truncate', task.status === 'completed' && 'line-through text-muted-foreground']">
              {{ task.title }}
            </p>
            <p v-if="task.start_time" class="text-[10px] sm:text-xs text-muted-foreground mt-0.5 flex items-center gap-1">
              <Clock class="h-2.5 w-2.5 sm:h-3 sm:w-3" />
              {{ task.start_time?.slice(0, 5) }}
            </p>
          </div>
          <Badge v-if="task.task_type === 'timed'" variant="outline" class="shrink-0 text-[10px] sm:text-xs px-1.5 sm:px-2">
            {{ task.duration_minutes }}m
          </Badge>
        </div>
        <div v-if="todaysTasks.length > 5" class="pt-1.5 sm:pt-2">
          <Button variant="ghost" size="sm" class="w-full text-muted-foreground text-xs sm:text-sm" @click="!isEditMode && router.push('/calendar')">
            +{{ todaysTasks.length - 5 }} more tasks
          </Button>
        </div>
      </div>
    </CardContent>
  </div>
</template>

