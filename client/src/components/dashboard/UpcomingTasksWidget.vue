<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { CalendarDays, ChevronRight, Clock } from 'lucide-vue-next'
import { format, addDays, isToday, isTomorrow } from 'date-fns'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { api } from '@/services/api'
import type { Task } from '@/types'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()
const upcomingTasks = ref<Task[]>([])
const loading = ref(false)

const formatDateLabel = (date: string) => {
  const d = new Date(date)
  if (isToday(d)) return 'Today'
  if (isTomorrow(d)) return 'Tomorrow'
  return format(d, 'EEE, MMM d')
}

onMounted(async () => {
  loading.value = true
  try {
    const today = format(new Date(), 'yyyy-MM-dd')
    const nextWeek = format(addDays(new Date(), 7), 'yyyy-MM-dd')
    const response = await api.listTasks({ 
      start_date: today, 
      end_date: nextWeek,
      status: 'not_started,in_progress'
    })
    upcomingTasks.value = response.data.slice(0, 6)
  } catch (error) {
    console.error('Failed to fetch upcoming tasks:', error)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="h-full flex flex-col">
    <CardHeader class="flex flex-row items-center justify-between pb-2 sm:pb-3 p-3 sm:p-4">
      <CardTitle class="text-sm sm:text-base font-medium flex items-center gap-2">
        <CalendarDays class="h-4 w-4 text-indigo-500" />
        Upcoming Tasks
      </CardTitle>
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
      <div v-if="loading" class="text-center py-8">
        <div class="animate-pulse text-muted-foreground text-sm">Loading...</div>
      </div>
      <div v-else-if="upcomingTasks.length === 0" class="text-center py-4">
        <div class="h-10 w-10 rounded-xl bg-indigo-500/10 mx-auto mb-2 flex items-center justify-center">
          <CalendarDays class="h-5 w-5 text-indigo-500/60" />
        </div>
        <p class="font-medium text-foreground text-sm">No upcoming tasks</p>
        <p class="text-xs text-muted-foreground mt-0.5">Your week is clear!</p>
      </div>
      <div v-else class="space-y-1">
        <div
          v-for="task in upcomingTasks"
          :key="task.id"
          class="flex items-center gap-3 p-2.5 rounded-lg hover:bg-secondary/60 transition-colors cursor-pointer"
          @click="!isEditMode && router.push('/calendar')"
        >
          <div 
            :class="[
              'status-dot shrink-0',
              task.status === 'in_progress' ? 'status-in-progress' : 'status-not-started'
            ]"
          />
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium truncate">{{ task.title }}</p>
            <p class="text-[10px] text-muted-foreground flex items-center gap-1">
              <Clock class="h-2.5 w-2.5" />
              {{ task.date ? formatDateLabel(task.date) : 'No date' }}
              <span v-if="task.start_time"> · {{ task.start_time.slice(0, 5) }}</span>
            </p>
          </div>
          <Badge v-if="task.priority > 1" variant="secondary" class="shrink-0 text-[10px]">
            P{{ task.priority }}
          </Badge>
        </div>
      </div>
    </CardContent>
  </div>
</template>

