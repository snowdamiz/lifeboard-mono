<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { format } from 'date-fns'
import { 
  Target, ArrowLeft, Plus, Calendar, CheckCircle2, Circle, 
  Trash2, Edit2, Flag, GripVertical, History
} from 'lucide-vue-next'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { useGoalsStore } from '@/stores/goals'

const route = useRoute()
const router = useRouter()
const goalsStore = useGoalsStore()

const newMilestoneTitle = ref('')
const addingMilestone = ref(false)

const goal = computed(() => goalsStore.currentGoal)

onMounted(async () => {
  const id = route.params.id as string
  await goalsStore.fetchGoal(id)
})

const handleAddMilestone = async () => {
  if (!newMilestoneTitle.value.trim() || !goal.value) return
  
  await goalsStore.addMilestone(goal.value.id, newMilestoneTitle.value)
  newMilestoneTitle.value = ''
  addingMilestone.value = false
}

const handleToggleMilestone = async (milestoneId: string) => {
  if (!goal.value) return
  await goalsStore.toggleMilestone(goal.value.id, milestoneId)
}

const handleDeleteMilestone = async (milestoneId: string) => {
  if (!goal.value) return
  await goalsStore.deleteMilestone(goal.value.id, milestoneId)
}

const getStatusColor = (status: string) => {
  switch (status) {
    case 'completed': return 'bg-emerald-500/10 text-emerald-600'
    case 'in_progress': return 'bg-amber-500/10 text-amber-600'
    case 'abandoned': return 'bg-red-500/10 text-red-600'
    default: return 'bg-muted text-muted-foreground'
  }
}

const getProgressColor = (progress: number) => {
  if (progress >= 75) return 'bg-emerald-500'
  if (progress >= 50) return 'bg-amber-500'
  if (progress >= 25) return 'bg-blue-500'
  return 'bg-muted-foreground/30'
}
</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in">
    <!-- Back button -->
    <Button variant="ghost" class="-ml-2" @click="router.push('/goals')">
      <ArrowLeft class="h-4 w-4 mr-1.5" />
      Back to Goals
    </Button>

    <!-- Loading -->
    <div v-if="goalsStore.loading && !goal" class="flex items-center justify-center py-12">
      <div class="h-6 w-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
    </div>

    <!-- Goal Content -->
    <div v-else-if="goal" class="space-y-4 sm:space-y-6">
      <!-- Header -->
      <div class="flex items-start gap-4">
        <div class="h-14 w-14 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
          <Target class="h-7 w-7 text-primary" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="flex items-start justify-between gap-3">
            <h1 class="text-2xl font-semibold tracking-tight">{{ goal.title }}</h1>
            <Badge :class="getStatusColor(goal.status)" class="shrink-0 text-sm uppercase">
              {{ goal.status.replace('_', ' ') }}
            </Badge>
          </div>
          <p v-if="goal.description" class="text-muted-foreground mt-1">{{ goal.description }}</p>
          
          <div class="flex items-center gap-4 mt-3 text-sm text-muted-foreground">

            <span v-if="goal.target_date" class="flex items-center gap-1.5">
              <Calendar class="h-4 w-4" />
              Target: {{ format(new Date(goal.target_date), 'MMMM d, yyyy') }}
            </span>
            <Button 
              variant="ghost" 
              size="sm" 
              class="h-7 px-2 text-muted-foreground hover:text-foreground"
              @click="router.push(`/goals/${goal.id}/history`)"
            >
              <History class="h-4 w-4 mr-1" />
              History
            </Button>
          </div>
        </div>
      </div>

      <!-- Progress Section -->
      <Card>
        <CardContent class="p-5">
          <div class="flex items-center justify-between mb-3">
            <h2 class="font-semibold">Overall Progress</h2>
            <span class="text-2xl font-bold">{{ goal.progress }}%</span>
          </div>
          <div class="h-3 bg-secondary rounded-full overflow-hidden">
            <div 
              :class="['h-full rounded-full transition-all duration-500', getProgressColor(goal.progress)]"
              :style="{ width: `${goal.progress}%` }"
            />
          </div>
          <p class="text-sm text-muted-foreground mt-2">
            {{ goal.milestones.filter(m => m.completed).length }} of {{ goal.milestones.length }} milestones completed
          </p>
        </CardContent>
      </Card>

      <!-- Milestones Section -->
      <Card>
        <CardContent class="p-5">
          <div class="flex items-center justify-between mb-4">
            <h2 class="font-semibold">Milestones</h2>
            <Button size="sm" variant="outline" @click="addingMilestone = true" v-if="!addingMilestone">
              <Plus class="h-4 w-4 mr-1" />
              Add Milestone
            </Button>
          </div>

          <!-- Add Milestone Form -->
          <div v-if="addingMilestone" class="flex gap-2 mb-4">
            <Input 
              v-model="newMilestoneTitle" 
              placeholder="Enter milestone title..." 
              class="flex-1"
              @keyup.enter="handleAddMilestone"
            />
            <Button @click="handleAddMilestone" :disabled="!newMilestoneTitle.trim()">Add</Button>
            <Button variant="ghost" @click="addingMilestone = false">Cancel</Button>
          </div>

          <!-- Milestones List -->
          <div v-if="goal.milestones.length === 0 && !addingMilestone" class="text-center py-8">
            <p class="text-muted-foreground">No milestones yet</p>
            <Button variant="outline" class="mt-3" @click="addingMilestone = true">
              <Plus class="h-4 w-4 mr-1.5" />
              Add your first milestone
            </Button>
          </div>

          <div v-else class="space-y-2">
            <div 
              v-for="milestone in goal.milestones" 
              :key="milestone.id"
              :class="[
                'flex items-center gap-3 p-3 rounded-lg transition-all',
                milestone.completed ? 'bg-primary/5' : 'hover:bg-secondary/50'
              ]"
            >
              <button 
                @click="handleToggleMilestone(milestone.id)"
                class="shrink-0 focus:outline-none"
              >
                <CheckCircle2 
                  v-if="milestone.completed" 
                  class="h-5 w-5 text-primary" 
                />
                <Circle 
                  v-else 
                  class="h-5 w-5 text-muted-foreground/40 hover:text-muted-foreground" 
                />
              </button>
              <span 
                :class="[
                  'flex-1 text-sm',
                  milestone.completed && 'line-through text-muted-foreground'
                ]"
              >
                {{ milestone.title }}
              </span>
              <span v-if="milestone.completed && milestone.completed_at" class="text-xs text-muted-foreground">
                {{ format(new Date(milestone.completed_at), 'MMM d') }}
              </span>
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 text-muted-foreground hover:text-destructive opacity-0 group-hover:opacity-100"
                @click="handleDeleteMilestone(milestone.id)"
              >
                <Trash2 class="h-4 w-4" />
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Not Found -->
    <div v-else class="text-center py-16">
      <p class="text-muted-foreground">Goal not found</p>
      <Button variant="outline" class="mt-4" @click="router.push('/goals')">
        Back to Goals
      </Button>
    </div>
  </div>
</template>

