<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { format } from 'date-fns'
import { 
  History, ArrowLeft, CheckCircle2, Circle, ArrowRight, 
  Trophy, Clock, User, Flag
} from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { useGoalsStore } from '@/stores/goals'
import type { GoalHistoryItem } from '@/types'

const route = useRoute()
const router = useRouter()
const goalsStore = useGoalsStore()

const history = ref<GoalHistoryItem[]>([])
const loading = ref(true)

const goalId = computed(() => route.params.id as string)

onMounted(async () => {
  loading.value = true
  try {
    await goalsStore.fetchGoal(goalId.value)
    history.value = await goalsStore.fetchGoalHistory(goalId.value)
  } finally {
    loading.value = false
  }
})

const getStatusColor = (status: string) => {
  switch (status) {
    case 'completed': return 'bg-emerald-500/10 text-emerald-600 border-emerald-500/30'
    case 'in_progress': return 'bg-amber-500/10 text-amber-600 border-amber-500/30'
    case 'abandoned': return 'bg-red-500/10 text-red-600 border-red-500/30'
    default: return 'bg-muted text-muted-foreground border-border'
  }
}

const getStatusLabel = (status: string | null | undefined) => {
  if (!status) return 'Created'
  return status.replace('_', ' ')
}
</script>

<template>
  <div class="space-y-6 animate-fade-in">
    <!-- Header -->
    <div class="flex items-center gap-4">
      <Button variant="ghost" size="icon" @click="router.back()">
        <ArrowLeft class="h-5 w-5" />
      </Button>
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <History class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Goal History</h1>
          <p class="text-sm text-muted-foreground" v-if="goalsStore.currentGoal">
            {{ goalsStore.currentGoal.title }}
          </p>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex items-center justify-center py-16">
      <div class="h-6 w-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
    </div>

    <!-- Empty State -->
    <div v-else-if="history.length === 0" class="text-center py-16">
      <div class="h-16 w-16 rounded-2xl bg-primary/5 mx-auto mb-4 flex items-center justify-center">
        <History class="h-8 w-8 text-primary/60" />
      </div>
      <h3 class="font-semibold text-lg">No history yet</h3>
      <p class="text-muted-foreground mt-1">Status changes and milestone completions will appear here</p>
    </div>

    <!-- Timeline -->
    <div v-else class="relative">
      <!-- Vertical line -->
      <div class="absolute left-6 top-0 bottom-0 w-0.5 bg-border" />

      <div class="space-y-6">
        <div 
          v-for="(item, index) in history" 
          :key="item.id"
          class="relative flex gap-4"
        >
          <!-- Timeline dot -->
          <div 
            :class="[
              'relative z-10 h-12 w-12 rounded-xl flex items-center justify-center shrink-0',
              item.type === 'status_change' ? 'bg-primary/10' : 'bg-emerald-500/10'
            ]"
          >
            <Trophy v-if="item.type === 'milestone_completed'" class="h-5 w-5 text-emerald-600" />
            <Flag v-else class="h-5 w-5 text-primary" />
          </div>

          <!-- Content -->
          <Card class="flex-1">
            <CardContent class="p-4">
              <!-- Status Change -->
              <template v-if="item.type === 'status_change'">
                <div class="flex items-center gap-2 flex-wrap">
                  <Badge :class="getStatusColor(item.from_status || '')" variant="outline">
                    {{ getStatusLabel(item.from_status) }}
                  </Badge>
                  <ArrowRight class="h-4 w-4 text-muted-foreground" />
                  <Badge :class="getStatusColor(item.to_status || '')" variant="outline">
                    {{ getStatusLabel(item.to_status) }}
                  </Badge>
                </div>
                <p v-if="item.notes" class="text-sm text-muted-foreground mt-2">
                  {{ item.notes }}
                </p>
              </template>

              <!-- Milestone Completed -->
              <template v-else-if="item.type === 'milestone_completed'">
                <div class="flex items-center gap-2">
                  <CheckCircle2 class="h-4 w-4 text-emerald-600" />
                  <span class="font-medium">Milestone completed</span>
                </div>
                <p class="text-sm text-muted-foreground mt-1">{{ item.title }}</p>
              </template>

              <!-- Meta -->
              <div class="flex items-center gap-4 mt-3 text-xs text-muted-foreground">
                <span class="flex items-center gap-1">
                  <Clock class="h-3 w-3" />
                  {{ format(new Date(item.timestamp), 'MMM d, yyyy h:mm a') }}
                </span>
                <span v-if="item.user" class="flex items-center gap-1">
                  <User class="h-3 w-3" />
                  {{ item.user.name || 'Unknown' }}
                </span>
              </div>
            </CardContent>
          </Card>
        </div>

        <!-- Goal Created marker -->
        <div class="relative flex gap-4">
          <div class="relative z-10 h-12 w-12 rounded-xl bg-secondary flex items-center justify-center shrink-0">
            <Circle class="h-5 w-5 text-muted-foreground" />
          </div>
          <Card class="flex-1">
            <CardContent class="p-4">
              <span class="font-medium">Goal created</span>
              <div class="flex items-center gap-1 mt-2 text-xs text-muted-foreground">
                <Clock class="h-3 w-3" />
                {{ goalsStore.currentGoal ? format(new Date(goalsStore.currentGoal.inserted_at), 'MMM d, yyyy h:mm a') : '' }}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  </div>
</template>


