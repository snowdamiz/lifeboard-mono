<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { format, subDays, eachDayOfInterval, isSameDay, startOfWeek, endOfWeek } from 'date-fns'
import { 
  Flame, Plus, CheckCircle2, Circle, Trash2, Edit2, Trophy, Zap, Calendar
} from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import { useHabitsStore, type HabitWithStatus } from '@/stores/habits'
import type { Habit } from '@/types'

const habitsStore = useHabitsStore()

const showCreateModal = ref(false)
const showEditModal = ref(false)
const editingHabit = ref<HabitWithStatus | null>(null)

const newHabit = ref({
  name: '',
  description: '',
  frequency: 'daily',
  color: '#10b981',
  days_of_week: [] as number[]
})

const colors = [
  '#10b981', '#06b6d4', '#3b82f6', '#8b5cf6', 
  '#ec4899', '#f43f5e', '#f97316', '#eab308'
]

const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

// Last 7 days for mini heatmap
const last7Days = computed(() => {
  const today = new Date()
  return eachDayOfInterval({
    start: subDays(today, 6),
    end: today
  })
})

onMounted(async () => {
  await habitsStore.fetchHabits()
})

const handleCreateHabit = async () => {
  if (!newHabit.value.name.trim()) return
  
  await habitsStore.createHabit({
    name: newHabit.value.name,
    description: newHabit.value.description || null,
    frequency: newHabit.value.frequency as 'daily' | 'weekly',
    color: newHabit.value.color,
    days_of_week: newHabit.value.frequency === 'weekly' ? newHabit.value.days_of_week : null
  })
  
  newHabit.value = { name: '', description: '', frequency: 'daily', color: '#10b981', days_of_week: [] }
  showCreateModal.value = false
}

const handleUpdateHabit = async () => {
  if (!editingHabit.value) return
  
  await habitsStore.updateHabit(editingHabit.value.id, {
    name: editingHabit.value.name,
    description: editingHabit.value.description,
    frequency: editingHabit.value.frequency,
    color: editingHabit.value.color,
    days_of_week: editingHabit.value.frequency === 'weekly' ? editingHabit.value.days_of_week : null
  })
  
  showEditModal.value = false
  editingHabit.value = null
}

const handleDeleteHabit = async (id: string) => {
  if (confirm('Are you sure you want to delete this habit?')) {
    await habitsStore.deleteHabit(id)
  }
}

const handleToggleComplete = async (habit: HabitWithStatus) => {
  if (habit.completed_today) {
    await habitsStore.uncompleteHabit(habit.id)
  } else {
    await habitsStore.completeHabit(habit.id)
  }
}

const openEditModal = (habit: HabitWithStatus) => {
  editingHabit.value = { ...habit }
  showEditModal.value = true
}

const toggleDayOfWeek = (day: number, model: { days_of_week: number[] }) => {
  const index = model.days_of_week.indexOf(day)
  if (index === -1) {
    model.days_of_week.push(day)
  } else {
    model.days_of_week.splice(index, 1)
  }
}
</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Flame class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Habits</h1>
          <p class="text-sm text-muted-foreground">Build consistency with daily habits</p>
        </div>
      </div>
      <Button @click="showCreateModal = true">
        <Plus class="h-4 w-4 mr-1.5" />
        New Habit
      </Button>
    </div>

    <!-- Stats -->
    <div class="grid gap-3 sm:gap-4 grid-cols-2 lg:grid-cols-4">
      <Card>
        <CardContent class="p-4">
          <div class="flex items-center gap-3">
            <div class="h-9 w-9 rounded-lg bg-primary/10 flex items-center justify-center">
              <Flame class="h-5 w-5 text-primary" />
            </div>
            <div>
              <p class="text-2xl font-bold">{{ habitsStore.habits.length }}</p>
              <p class="text-xs text-muted-foreground">Total Habits</p>
            </div>
          </div>
        </CardContent>
      </Card>
      
      <Card>
        <CardContent class="p-4">
          <div class="flex items-center gap-3">
            <div class="h-9 w-9 rounded-lg bg-emerald-500/10 flex items-center justify-center">
              <CheckCircle2 class="h-5 w-5 text-emerald-600" />
            </div>
            <div>
              <p class="text-2xl font-bold">{{ habitsStore.completedToday.length }}</p>
              <p class="text-xs text-muted-foreground">Done Today</p>
            </div>
          </div>
        </CardContent>
      </Card>
      
      <Card>
        <CardContent class="p-4">
          <div class="flex items-center gap-3">
            <div class="h-9 w-9 rounded-lg bg-amber-500/10 flex items-center justify-center">
              <Zap class="h-5 w-5 text-amber-600" />
            </div>
            <div>
              <p class="text-2xl font-bold">{{ habitsStore.totalStreak }}</p>
              <p class="text-xs text-muted-foreground">Total Streaks</p>
            </div>
          </div>
        </CardContent>
      </Card>
      
      <Card>
        <CardContent class="p-4">
          <div class="flex items-center gap-3">
            <div class="h-9 w-9 rounded-lg bg-violet-500/10 flex items-center justify-center">
              <Trophy class="h-5 w-5 text-violet-600" />
            </div>
            <div>
              <p class="text-2xl font-bold">
                {{ habitsStore.habits.length > 0 
                  ? Math.round((habitsStore.completedToday.length / habitsStore.habits.length) * 100) 
                  : 0 }}%
              </p>
              <p class="text-xs text-muted-foreground">Today's Progress</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Habits List -->
    <div v-if="habitsStore.loading" class="flex items-center justify-center py-12">
      <div class="h-6 w-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
    </div>

    <div v-else-if="habitsStore.habits.length === 0" class="text-center py-16">
      <div class="h-16 w-16 rounded-2xl bg-orange-500/5 mx-auto mb-4 flex items-center justify-center">
        <Flame class="h-8 w-8 text-orange-500/60" />
      </div>
      <h3 class="font-semibold text-lg">No habits yet</h3>
      <p class="text-muted-foreground mt-1">Start building better habits today</p>
      <Button variant="outline" class="mt-4" @click="showCreateModal = true">
        <Plus class="h-4 w-4 mr-1.5" />
        Create your first habit
      </Button>
    </div>

    <div v-else class="grid gap-3">
      <Card 
        v-for="habit in habitsStore.habits" 
        :key="habit.id" 
        class="group hover:shadow-md transition-all"
      >
        <CardContent class="p-4">
          <div class="flex items-center gap-4">
            <!-- Complete button -->
            <button 
              @click="handleToggleComplete(habit)"
              class="shrink-0 focus:outline-none"
            >
              <div 
                v-if="habit.completed_today"
                class="h-10 w-10 rounded-xl flex items-center justify-center transition-all"
                :style="{ backgroundColor: habit.color + '20' }"
              >
                <CheckCircle2 class="h-6 w-6" :style="{ color: habit.color }" />
              </div>
              <div 
                v-else
                class="h-10 w-10 rounded-xl border-2 border-dashed border-muted-foreground/30 flex items-center justify-center hover:border-muted-foreground/50 transition-all"
              >
                <Circle class="h-6 w-6 text-muted-foreground/30" />
              </div>
            </button>
            
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <h3 
                  :class="[
                    'font-semibold text-base',
                    habit.completed_today && 'line-through text-muted-foreground'
                  ]"
                >
                  {{ habit.name }}
                </h3>
                <Badge v-if="habit.streak_count > 0" variant="secondary" class="text-xs">
                  <Flame class="h-3 w-3 mr-0.5" :style="{ color: habit.color }" />
                  {{ habit.streak_count }} day{{ habit.streak_count !== 1 ? 's' : '' }}
                </Badge>
              </div>
              <p v-if="habit.description" class="text-sm text-muted-foreground mt-0.5 line-clamp-1">
                {{ habit.description }}
              </p>
              
              <!-- Mini heatmap for last 7 days -->
              <div class="flex items-center gap-1 mt-2">
                <div 
                  v-for="day in last7Days" 
                  :key="day.toISOString()"
                  class="w-5 h-5 rounded"
                  :class="habit.completed_today && isSameDay(day, new Date()) ? '' : 'bg-secondary'"
                  :style="habit.completed_today && isSameDay(day, new Date()) ? { backgroundColor: habit.color + '40' } : {}"
                  :title="format(day, 'MMM d')"
                />
              </div>
            </div>

            <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 text-muted-foreground"
                @click="openEditModal(habit)"
              >
                <Edit2 class="h-4 w-4" />
              </Button>
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 text-destructive"
                @click="handleDeleteHabit(habit.id)"
              >
                <Trash2 class="h-4 w-4" />
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Create Habit Modal -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div 
          v-if="showCreateModal"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          @click="showCreateModal = false"
        >
          <div 
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Create New Habit</h2>
            </div>
            <div class="p-5 space-y-4">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Name</label>
                <Input v-model="newHabit.name" placeholder="e.g., Morning exercise" />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Description (optional)</label>
                <Input v-model="newHabit.description" placeholder="What does this habit involve?" />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Frequency</label>
                <Select 
                  v-model="newHabit.frequency"
                  :options="[
                    { value: 'daily', label: 'Daily' },
                    { value: 'weekly', label: 'Weekly (specific days)' }
                  ]"
                  placeholder="Select frequency"
                />
              </div>
              <div v-if="newHabit.frequency === 'weekly'">
                <label class="text-sm font-medium mb-1.5 block">Days of Week</label>
                <div class="flex gap-1">
                  <button
                    v-for="(day, index) in weekDays"
                    :key="index"
                    :class="[
                      'flex-1 py-1.5 text-xs font-medium rounded transition-all',
                      newHabit.days_of_week.includes(index)
                        ? 'bg-primary text-primary-foreground'
                        : 'bg-secondary text-muted-foreground hover:bg-secondary/80'
                    ]"
                    @click="toggleDayOfWeek(index, newHabit)"
                  >
                    {{ day }}
                  </button>
                </div>
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Color</label>
                <div class="flex gap-2">
                  <button
                    v-for="color in colors"
                    :key="color"
                    class="w-8 h-8 rounded-lg transition-all"
                    :class="newHabit.color === color ? 'ring-2 ring-offset-2 ring-offset-background' : 'hover:scale-110'"
                    :style="{ backgroundColor: color, '--tw-ring-color': color } as any"
                    @click="newHabit.color = color"
                  />
                </div>
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showCreateModal = false">Cancel</Button>
              <Button @click="handleCreateHabit" :disabled="!newHabit.name.trim()">Create Habit</Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Edit Habit Modal -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div 
          v-if="showEditModal && editingHabit"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          @click="showEditModal = false"
        >
          <div 
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Edit Habit</h2>
            </div>
            <div class="p-5 space-y-4">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Name</label>
                <Input v-model="editingHabit.name" />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Description</label>
                <Input :model-value="editingHabit.description ?? ''" @update:model-value="editingHabit.description = $event || null" />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Color</label>
                <div class="flex gap-2">
                  <button
                    v-for="color in colors"
                    :key="color"
                    class="w-8 h-8 rounded-lg transition-all"
                    :class="editingHabit.color === color ? 'ring-2 ring-offset-2 ring-offset-background' : 'hover:scale-110'"
                    :style="{ backgroundColor: color, '--tw-ring-color': color } as any"
                    @click="editingHabit.color = color"
                  />
                </div>
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showEditModal = false">Cancel</Button>
              <Button @click="handleUpdateHabit">Save Changes</Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

