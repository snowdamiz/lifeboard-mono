<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Target, ChevronRight, Flag } from 'lucide-vue-next'
import { CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { useGoalsStore } from '@/stores/goals'

const props = defineProps<{
  isEditMode: boolean
}>()

const router = useRouter()
const goalsStore = useGoalsStore()

const activeGoals = computed(() => goalsStore.activeGoals.slice(0, 4))

onMounted(() => {
  if (goalsStore.goals.length === 0) {
    goalsStore.fetchGoals()
  }
})
</script>

<template>
  <div class="h-full flex flex-col">
    <CardHeader class="flex flex-row items-center justify-between pb-2 sm:pb-3 p-3 sm:p-4">
      <CardTitle class="text-sm sm:text-base font-medium flex items-center gap-2">
        <Target class="h-4 w-4 text-blue-500" />
        Active Goals
      </CardTitle>
      <Button 
        variant="ghost" 
        size="sm" 
        class="text-muted-foreground hover:text-foreground -mr-2 h-8 px-2 sm:px-3" 
        @click="!isEditMode && router.push('/goals')"
      >
        <span class="hidden sm:inline">View all</span>
        <ChevronRight class="h-4 w-4 sm:ml-0.5" />
      </Button>
    </CardHeader>
    <CardContent class="pt-0 p-3 sm:p-4 sm:pt-0 flex-1 overflow-auto">
      <div v-if="activeGoals.length === 0" class="text-center py-4">
        <div class="h-10 w-10 rounded-xl bg-blue-500/10 mx-auto mb-2 flex items-center justify-center">
          <Flag class="h-5 w-5 text-blue-500/60" />
        </div>
        <p class="font-medium text-foreground text-sm">No active goals</p>
        <p class="text-xs text-muted-foreground mt-0.5">Set a goal to get started</p>
        <Button variant="outline" size="sm" class="mt-2 h-7 text-xs" @click="!isEditMode && router.push('/goals')">
          Add a goal
        </Button>
      </div>
      <div v-else class="space-y-3">
        <div
          v-for="goal in activeGoals"
          :key="goal.id"
          class="p-3 rounded-lg hover:bg-secondary/60 transition-colors cursor-pointer"
          @click="!isEditMode && router.push(`/goals/${goal.id}`)"
        >
          <div class="flex items-start justify-between gap-2 mb-2">
            <p class="text-sm font-medium truncate flex-1">{{ goal.title }}</p>
            <span class="text-xs text-muted-foreground tabular-nums shrink-0">{{ goal.progress }}%</span>
          </div>
          <div class="h-1.5 bg-secondary rounded-full overflow-hidden">
            <div 
              class="h-full bg-blue-500 rounded-full transition-all duration-500"
              :style="{ width: `${goal.progress}%` }"
            />
          </div>
          <p v-if="goal.target_date" class="text-[10px] text-muted-foreground mt-1.5">
            Target: {{ new Date(goal.target_date).toLocaleDateString() }}
          </p>
        </div>
      </div>
    </CardContent>
  </div>
</template>

