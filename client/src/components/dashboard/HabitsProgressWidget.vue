<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Flame, Check, Circle } from 'lucide-vue-next'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { useHabitsStore } from '@/stores/habits'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()
const habitsStore = useHabitsStore()

const completionRate = computed(() => {
  if (habitsStore.habits.length === 0) return 0
  return Math.round((habitsStore.completedToday.length / habitsStore.habits.length) * 100)
})

const handleClick = () => {
  if (!props.isEditMode) {
    router.push('/habits')
  }
}

onMounted(() => {
  if (habitsStore.habits.length === 0) {
    habitsStore.fetchHabits()
  }
})
</script>

<template>
  <div 
    class="h-full cursor-pointer"
    @click="handleClick"
  >
    <CardHeader class="flex flex-row items-center justify-between pb-1.5 sm:pb-2 p-3 sm:p-4">
      <CardTitle class="text-[11px] sm:text-[13px] font-medium text-muted-foreground">Today's Habits</CardTitle>
      <div class="h-7 w-7 sm:h-9 sm:w-9 rounded-lg bg-orange-500/10 flex items-center justify-center">
        <Flame class="h-3.5 w-3.5 sm:h-4 sm:w-4 text-orange-600" />
      </div>
    </CardHeader>
    <CardContent class="p-3 pt-0 sm:p-4 sm:pt-0">
      <div class="flex items-baseline gap-1.5 sm:gap-2">
        <span class="text-2xl sm:text-3xl font-semibold tracking-tight tabular-nums">{{ habitsStore.completedToday.length }}</span>
        <span class="text-[10px] sm:text-xs text-muted-foreground">/ {{ habitsStore.habits.length }} done</span>
      </div>
      <div class="flex items-center gap-2 mt-1.5 sm:mt-2">
        <div class="flex-1 h-1 sm:h-1.5 bg-secondary rounded-full overflow-hidden">
          <div 
            class="h-full bg-orange-500 rounded-full transition-all duration-500"
            :style="{ width: `${completionRate}%` }"
          />
        </div>
        <span class="text-[10px] sm:text-xs text-muted-foreground tabular-nums">{{ completionRate }}%</span>
      </div>
      
      <!-- Habit dots -->
      <div v-if="habitsStore.habits.length > 0" class="flex flex-wrap gap-1.5 mt-3">
        <div
          v-for="habit in habitsStore.habits.slice(0, 8)"
          :key="habit.id"
          :title="habit.name"
          :class="[
            'w-5 h-5 rounded-full flex items-center justify-center transition-colors',
            habit.completed_today 
              ? 'bg-orange-500 text-white' 
              : 'bg-secondary text-muted-foreground'
          ]"
        >
          <Check v-if="habit.completed_today" class="h-3 w-3" />
          <Circle v-else class="h-2 w-2" />
        </div>
        <div 
          v-if="habitsStore.habits.length > 8" 
          class="w-5 h-5 rounded-full bg-secondary flex items-center justify-center text-[10px] text-muted-foreground"
        >
          +{{ habitsStore.habits.length - 8 }}
        </div>
      </div>
    </CardContent>
  </div>
</template>

