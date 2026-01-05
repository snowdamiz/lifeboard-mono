<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Flame, Trophy, ChevronRight } from 'lucide-vue-next'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { useHabitsStore } from '@/stores/habits'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()
const habitsStore = useHabitsStore()

const topStreaks = computed(() => {
  return [...habitsStore.habits]
    .sort((a, b) => b.streak_count - a.streak_count)
    .slice(0, 5)
})

const totalStreak = computed(() => habitsStore.totalStreak)

onMounted(() => {
  if (habitsStore.habits.length === 0) {
    habitsStore.fetchHabits()
  }
})
</script>

<template>
  <div class="h-full flex flex-col">
    <CardHeader class="flex flex-row items-center justify-between pb-2 sm:pb-3 p-3 sm:p-4">
      <CardTitle class="text-sm sm:text-base font-medium flex items-center gap-2">
        <Trophy class="h-4 w-4 text-yellow-500" />
        Habit Streaks
      </CardTitle>
      <Button 
        variant="ghost" 
        size="sm" 
        class="text-muted-foreground hover:text-foreground -mr-2 h-8 px-2 sm:px-3" 
        @click="!isEditMode && router.push('/habits')"
      >
        <ChevronRight class="h-4 w-4" />
      </Button>
    </CardHeader>
    <CardContent class="pt-0 p-3 sm:p-4 sm:pt-0 flex-1 overflow-auto">
      <div v-if="topStreaks.length === 0" class="text-center py-4">
        <div class="h-10 w-10 rounded-xl bg-yellow-500/10 mx-auto mb-2 flex items-center justify-center">
          <Flame class="h-5 w-5 text-yellow-500/60" />
        </div>
        <p class="font-medium text-foreground text-sm">No habits yet</p>
        <p class="text-xs text-muted-foreground mt-0.5">Start building streaks</p>
        <Button variant="outline" size="sm" class="mt-2 h-7 text-xs" @click="!isEditMode && router.push('/habits')">
          Add habit
        </Button>
      </div>
      <div v-else>
        <!-- Total streak summary -->
        <div class="flex items-center justify-center gap-2 mb-4 p-3 rounded-lg bg-gradient-to-r from-yellow-500/10 to-orange-500/10">
          <Flame class="h-5 w-5 text-orange-500" />
          <span class="text-2xl font-bold text-orange-600 tabular-nums">{{ totalStreak }}</span>
          <span class="text-sm text-muted-foreground">total days</span>
        </div>
        
        <!-- Streak leaderboard -->
        <div class="space-y-2">
          <div
            v-for="(habit, index) in topStreaks"
            :key="habit.id"
            class="flex items-center gap-3 p-2 rounded-lg hover:bg-secondary/60 transition-colors cursor-pointer"
            @click="!isEditMode && router.push('/habits')"
          >
            <div :class="[
              'w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold shrink-0',
              index === 0 ? 'bg-yellow-500 text-yellow-950' :
              index === 1 ? 'bg-gray-300 text-gray-700' :
              index === 2 ? 'bg-amber-600 text-amber-50' :
              'bg-secondary text-muted-foreground'
            ]">
              {{ index + 1 }}
            </div>
            <div 
              class="w-3 h-3 rounded-full shrink-0"
              :style="{ backgroundColor: habit.color }"
            />
            <span class="flex-1 text-sm truncate">{{ habit.name }}</span>
            <div class="flex items-center gap-1 text-orange-600">
              <Flame class="h-3.5 w-3.5" />
              <span class="text-sm font-medium tabular-nums">{{ habit.streak_count }}</span>
            </div>
          </div>
        </div>
      </div>
    </CardContent>
  </div>
</template>

