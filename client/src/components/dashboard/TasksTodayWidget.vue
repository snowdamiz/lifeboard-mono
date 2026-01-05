<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { Calendar } from 'lucide-vue-next'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { useCalendarStore } from '@/stores/calendar'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()
const calendarStore = useCalendarStore()

const todaysTasks = computed(() => calendarStore.todaysTasks)

const completedTasksToday = computed(() => 
  todaysTasks.value.filter(t => t.status === 'completed').length
)

const taskProgress = computed(() => {
  if (todaysTasks.value.length === 0) return 0
  return Math.round((completedTasksToday.value / todaysTasks.value.length) * 100)
})

const handleClick = () => {
  if (!props.isEditMode) {
    router.push('/calendar')
  }
}
</script>

<template>
  <div 
    class="h-full cursor-pointer"
    @click="handleClick"
  >
    <CardHeader class="flex flex-row items-center justify-between pb-1.5 sm:pb-2 p-3 sm:p-4">
      <CardTitle class="text-[11px] sm:text-[13px] font-medium text-muted-foreground">Today's Tasks</CardTitle>
      <div class="h-7 w-7 sm:h-9 sm:w-9 rounded-lg bg-primary/10 flex items-center justify-center">
        <Calendar class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-primary" />
      </div>
    </CardHeader>
    <CardContent class="p-3 pt-0 sm:p-4 sm:pt-0">
      <div class="flex items-baseline gap-1.5 sm:gap-2">
        <span class="text-2xl sm:text-3xl font-semibold tracking-tight tabular-nums">{{ todaysTasks.length }}</span>
        <span v-if="todaysTasks.length > 0" class="text-[10px] sm:text-xs text-muted-foreground">tasks</span>
      </div>
      <div class="flex items-center gap-2 mt-1.5 sm:mt-2">
        <div class="flex-1 h-1 sm:h-1.5 bg-secondary rounded-full overflow-hidden">
          <div 
            class="h-full bg-primary rounded-full transition-all duration-500"
            :style="{ width: `${taskProgress}%` }"
          />
        </div>
        <span class="text-[10px] sm:text-xs text-muted-foreground tabular-nums">{{ completedTasksToday }}/{{ todaysTasks.length }}</span>
      </div>
    </CardContent>
  </div>
</template>

