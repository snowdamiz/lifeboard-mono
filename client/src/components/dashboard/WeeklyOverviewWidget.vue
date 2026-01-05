<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { CalendarRange, ChevronRight } from 'lucide-vue-next'
import { format, startOfWeek, addDays, isSameDay } from 'date-fns'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { api } from '@/services/api'
import type { Task } from '@/types'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()
const weekTasks = ref<Task[]>([])
const loading = ref(false)

const weekDays = computed(() => {
  const start = startOfWeek(new Date(), { weekStartsOn: 1 }) // Monday
  return Array.from({ length: 7 }, (_, i) => {
    const date = addDays(start, i)
    const dayTasks = weekTasks.value.filter(t => t.date && isSameDay(new Date(t.date), date))
    const completed = dayTasks.filter(t => t.status === 'completed').length
    return {
      date,
      label: format(date, 'EEE'),
      dayNum: format(date, 'd'),
      isToday: isSameDay(date, new Date()),
      taskCount: dayTasks.length,
      completedCount: completed
    }
  })
})

const weekProgress = computed(() => {
  if (weekTasks.value.length === 0) return 0
  const completed = weekTasks.value.filter(t => t.status === 'completed').length
  return Math.round((completed / weekTasks.value.length) * 100)
})

onMounted(async () => {
  loading.value = true
  try {
    const start = startOfWeek(new Date(), { weekStartsOn: 1 })
    const end = addDays(start, 6)
    const response = await api.listTasks({ 
      start_date: format(start, 'yyyy-MM-dd'), 
      end_date: format(end, 'yyyy-MM-dd')
    })
    weekTasks.value = response.data
  } catch (error) {
    console.error('Failed to fetch week tasks:', error)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="h-full flex flex-col">
    <CardHeader class="flex flex-row items-center justify-between pb-2 sm:pb-3 p-3 sm:p-4">
      <CardTitle class="text-sm sm:text-base font-medium flex items-center gap-2">
        <CalendarRange class="h-4 w-4 text-teal-500" />
        This Week
      </CardTitle>
      <Button 
        variant="ghost" 
        size="sm" 
        class="text-muted-foreground hover:text-foreground -mr-2 h-8 px-2 sm:px-3" 
        @click="!isEditMode && router.push('/calendar')"
      >
        <ChevronRight class="h-4 w-4" />
      </Button>
    </CardHeader>
    <CardContent class="pt-0 p-3 sm:p-4 sm:pt-0 flex-1">
      <!-- Week progress -->
      <div class="flex items-center gap-2 mb-4">
        <div class="flex-1 h-2 bg-secondary rounded-full overflow-hidden">
          <div 
            class="h-full bg-teal-500 rounded-full transition-all duration-500"
            :style="{ width: `${weekProgress}%` }"
          />
        </div>
        <span class="text-xs text-muted-foreground tabular-nums">{{ weekProgress }}%</span>
      </div>

      <!-- Week days grid -->
      <div class="grid grid-cols-7 gap-1">
        <div
          v-for="day in weekDays"
          :key="day.label"
          :class="[
            'text-center p-2 rounded-lg transition-colors cursor-pointer',
            day.isToday ? 'bg-teal-500/10 ring-1 ring-teal-500/30' : 'hover:bg-secondary/60'
          ]"
          @click="!isEditMode && router.push('/calendar')"
        >
          <div :class="['text-[10px] font-medium mb-1', day.isToday ? 'text-teal-600' : 'text-muted-foreground']">
            {{ day.label }}
          </div>
          <div :class="['text-lg font-semibold tabular-nums', day.isToday ? 'text-teal-600' : 'text-foreground']">
            {{ day.dayNum }}
          </div>
          <div v-if="day.taskCount > 0" class="mt-1">
            <div class="flex justify-center gap-0.5">
              <div 
                v-for="i in Math.min(day.taskCount, 3)" 
                :key="i"
                :class="[
                  'w-1.5 h-1.5 rounded-full',
                  i <= day.completedCount ? 'bg-teal-500' : 'bg-secondary'
                ]"
              />
            </div>
            <div v-if="day.taskCount > 3" class="text-[9px] text-muted-foreground mt-0.5">
              +{{ day.taskCount - 3 }}
            </div>
          </div>
        </div>
      </div>

      <!-- Summary -->
      <div class="mt-4 pt-3 border-t flex justify-between text-xs text-muted-foreground">
        <span>{{ weekTasks.length }} tasks</span>
        <span>{{ weekTasks.filter(t => t.status === 'completed').length }} completed</span>
      </div>
    </CardContent>
  </div>
</template>

