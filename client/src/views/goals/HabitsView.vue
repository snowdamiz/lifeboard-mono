<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { format, subDays, eachDayOfInterval, isSameDay, startOfWeek, endOfWeek } from 'date-fns'
import { 
  Flame, Plus, CheckCircle2, Circle, Trash2, Edit2, Trophy, Zap, Calendar, Filter,
  PlusCircle, MinusCircle, X
} from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import TagManager from '@/components/shared/TagManager.vue'
import CollapsibleTagManager from '@/components/shared/CollapsibleTagManager.vue'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import { useHabitsStore, type HabitWithStatus } from '@/stores/habits'
import { useTagsStore } from '@/stores/tags'
import { useTextTemplate } from '@/composables/useTextTemplate'
import type { Habit, Tag } from '@/types'

const habitsStore = useHabitsStore()
const tagsStore = useTagsStore()

// Template composables
const habitTitleTemplate = useTextTemplate('habit_title')
const habitDescriptionTemplate = useTextTemplate('habit_description')

const showCreateModal = ref(false)
const showEditModal = ref(false)
const editingHabit = ref<HabitWithStatus & { tag_ids: Set<string> } | null>(null)
const expandedHabitId = ref<string | null>(null)

const newHabit = ref({
  name: '',
  description: '',
  frequency: 'daily',
  color: '#10b981',
  days_of_week: [] as number[],
  tag_ids: new Set<string>()
})

// Tag selection state
const tempSelectedTags = ref<Set<string>>(new Set())
const isCreateTagsExpanded = ref(false)
const isEditTagsExpanded = ref(false)

// Helper to resolve tag objects from IDs
const resolveTags = (tagIds: Set<string>): Tag[] => {
  return Array.from(tagIds).map(id => tagsStore.tags.find(t => t.id === id)).filter(Boolean) as Tag[]
}

const handleAddTags = (targetSet: Set<string>, tagsToAdd: Set<string>) => {
  tagsToAdd.forEach(id => targetSet.add(id))
}

const handleRemoveTag = (targetSet: Set<string>, tagId: string) => {
  targetSet.delete(tagId)
}

// Toggle habit expansion
const toggleHabitExpand = (habitId: string, event: MouseEvent) => {
  // Don't toggle if clicking on action buttons
  const target = event.target as HTMLElement
  if (target.closest('button')) return
  
  expandedHabitId.value = expandedHabitId.value === habitId ? null : habitId
}

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

// Filtering Logic
const showFilterDropdown = ref(false)
const filterCheckedTagIds = ref<Set<string>>(new Set(habitsStore.filterTags))
const filterAppliedTagIds = computed(() => new Set<string>()) 

watch(() => habitsStore.filterTags, (newTags) => {
  filterCheckedTagIds.value = new Set(newTags)
})

const applyFilters = () => {
  habitsStore.filterTags = Array.from(filterCheckedTagIds.value)
  habitsStore.fetchHabits()
  showFilterDropdown.value = false
}

const clearFilters = () => {
  habitsStore.filterTags = []
  filterCheckedTagIds.value = new Set()
  habitsStore.fetchHabits()
  showFilterDropdown.value = false
}

const activeFilterCount = computed(() => habitsStore.filterTags.length)

onMounted(async () => {
  await habitsStore.fetchHabits()
})

const handleCreateHabit = async () => {
  if (!newHabit.value.name.trim()) return

  // Save templates
  habitTitleTemplate.save(newHabit.value.name)
  if (newHabit.value.description) {
      habitDescriptionTemplate.save(newHabit.value.description)
  }
  
  await habitsStore.createHabit({
    name: newHabit.value.name,
    description: newHabit.value.description || null,
    frequency: newHabit.value.frequency as 'daily' | 'weekly',
    color: newHabit.value.color,
    days_of_week: newHabit.value.frequency === 'weekly' ? newHabit.value.days_of_week : null,
    tag_ids: Array.from(newHabit.value.tag_ids)
  })
  
  newHabit.value = { name: '', description: '', frequency: 'daily', color: '#10b981', days_of_week: [], tag_ids: new Set() }
  tempSelectedTags.value = new Set()
  showCreateModal.value = false
}

watch(showCreateModal, (val) => {
  if (!val) {
    tempSelectedTags.value = new Set()
    isCreateTagsExpanded.value = false
  }
})

watch(showEditModal, (val) => {
  if (!val) {
    tempSelectedTags.value = new Set()
    isEditTagsExpanded.value = false
  }
})

const handleUpdateHabit = async () => {
  if (!editingHabit.value) return

  // Save templates
  habitTitleTemplate.save(editingHabit.value.name)
  if (editingHabit.value.description) {
      habitDescriptionTemplate.save(editingHabit.value.description)
  }
  
  await habitsStore.updateHabit(editingHabit.value.id, {
    name: editingHabit.value.name,
    description: editingHabit.value.description,
    frequency: editingHabit.value.frequency,
    color: editingHabit.value.color,
    days_of_week: editingHabit.value.frequency === 'weekly' ? editingHabit.value.days_of_week : null,
    tag_ids: Array.from(editingHabit.value.tag_ids)
  })
  
  showEditModal.value = false
  editingHabit.value = null
  tempSelectedTags.value = new Set()
}

watch(showEditModal, (val) => {
  if (!val) {
    tempSelectedTags.value = new Set()
  }
})

const handleDeleteHabit = async (id: string) => {
  await habitsStore.deleteHabit(id)
}

const handleToggleComplete = async (habit: HabitWithStatus) => {
  if (habit.completed_today) {
    await habitsStore.uncompleteHabit(habit.id)
  } else {
    await habitsStore.completeHabit(habit.id)
  }
}

const openEditModal = (habit: HabitWithStatus) => {
  // Map current tags to Set
  const tagIds = new Set(habit.tags?.map(t => t.id) || [])
  editingHabit.value = { ...habit, tag_ids: tagIds }
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
      
      <div class="flex items-center gap-2">
        <!-- Filter Button -->
        <div class="relative">
          <Button 
            :variant="activeFilterCount > 0 ? 'default' : 'outline'" 
            size="sm" 
            class="h-9 gap-2"
            @click="showFilterDropdown = !showFilterDropdown"
          >
            <Filter class="h-4 w-4" />
            <span class="hidden sm:inline">Filter</span>
            <Badge v-if="activeFilterCount > 0" variant="secondary" class="ml-0.5 h-5 px-1.5 min-w-[20px] justify-center bg-background/20 text-current border-0">
              {{ activeFilterCount }}
            </Badge>
          </Button>

          <!-- Filter Dropdown -->
          <div
            v-if="showFilterDropdown"
            class="absolute top-full right-0 mt-2 w-72 bg-card border border-border rounded-xl shadow-xl z-50 overflow-hidden"
          >
            <div class="p-3 border-b border-border bg-secondary/30 flex items-center justify-between">
              <span class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Filter by Tags</span>
              <button class="text-xs text-primary hover:underline" @click="clearFilters" v-if="activeFilterCount > 0">
                Clear all
              </button>
            </div>
            
            <TagManager
              ref="filterTagManagerRef"
              v-model:checkedTagIds="filterCheckedTagIds"
              :hide-input="true"
              :compact="true"
              :embedded="true"
              :applied-tag-ids="filterAppliedTagIds"
              class="max-h-[300px] overflow-auto"
            >
              <template #actions="{ checkedCount }">
                <Button
                  type="button"
                  size="sm"
                  class="w-full text-xs"
                  @click="applyFilters"
                >
                  Apply Filter
                </Button>
              </template>
            </TagManager>
          </div>
          <!-- Backdrop to close -->
          <div v-if="showFilterDropdown" class="fixed inset-0 z-40 bg-transparent" @click="showFilterDropdown = false" />
        </div>

        <Button @click="showCreateModal = true">
          <Plus class="h-4 w-4 mr-1.5" />
          New Habit
        </Button>
      </div>
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
      <h3 class="font-semibold text-lg">No habits found</h3>
      <p class="text-muted-foreground mt-1">
        {{ activeFilterCount > 0 ? 'Try clearing your filters' : 'Start building better habits today' }}
      </p>
      <Button variant="outline" class="mt-4" @click="activeFilterCount > 0 ? clearFilters() : (showCreateModal = true)">
        <component :is="activeFilterCount > 0 ? 'X' : Plus" class="h-4 w-4 mr-1.5" />
        {{ activeFilterCount > 0 ? 'Clear Filters' : 'Create your first habit' }}
      </Button>
    </div>

    <div v-else class="grid gap-3">
      <Card 
        v-for="habit in habitsStore.habits" 
        :key="habit.id" 
        class="group hover:shadow-md transition-all cursor-pointer"
        @click="toggleHabitExpand(habit.id, $event)"
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
              
              <!-- Tags display inline -->
              <div v-if="habit.tags && habit.tags.length > 0" class="flex flex-wrap gap-1 mt-1.5">
                <div 
                  v-for="tag in habit.tags.slice(0, 3)" 
                  :key="tag.id"
                  class="h-1.5 w-1.5 rounded-full"
                  :style="{ backgroundColor: tag.color }"
                  :title="tag.name"
                />
                <span v-if="habit.tags.length > 3" class="text-[10px] text-muted-foreground">+{{ habit.tags.length - 3 }}</span>
              </div>
              
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

            <div class="flex items-center gap-1 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 text-muted-foreground"
                @click.stop="openEditModal(habit)"
              >
                <Edit2 class="h-4 w-4" />
              </Button>
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 text-destructive"
                @click.stop="handleDeleteHabit(habit.id)"
              >
                <Trash2 class="h-4 w-4" />
              </Button>
            </div>
          </div>
          
          <!-- Expanded Details -->
          <Transition
            enter-active-class="transition-all duration-200 ease-out"
            enter-from-class="opacity-0 max-h-0"
            enter-to-class="opacity-100 max-h-96"
            leave-active-class="transition-all duration-150 ease-in"
            leave-from-class="opacity-100 max-h-96"
            leave-to-class="opacity-0 max-h-0"
          >
            <div v-if="expandedHabitId === habit.id" class="mt-4 pt-4 border-t border-border/60 space-y-3 overflow-hidden">
              <!-- Full description -->
              <div v-if="habit.description" class="text-sm text-muted-foreground">
                {{ habit.description }}
              </div>
              
              <!-- Tags Full List -->
              <div v-if="habit.tags && habit.tags.length > 0" class="flex flex-wrap gap-1">
                <Badge
                  v-for="tag in habit.tags"
                  :key="tag.id"
                  variant="secondary"
                  class="text-xs bg-secondary/50"
                >
                  <div class="h-1.5 w-1.5 rounded-full mr-1.5" :style="{ backgroundColor: tag.color }" />
                  {{ tag.name }}
                </Badge>
              </div>

              <!-- Habit details -->
              <div class="flex flex-wrap gap-2 text-xs">
                <Badge variant="outline">
                  <Calendar class="h-3 w-3 mr-1" />
                  {{ habit.frequency === 'daily' ? 'Every day' : 'Weekly' }}
                </Badge>
                <Badge v-if="habit.streak_count > 0" variant="secondary">
                  <Flame class="h-3 w-3 mr-1" :style="{ color: habit.color }" />
                  {{ habit.streak_count }} day streak
                </Badge>
              </div>
              
              <!-- Action buttons -->
              <div class="flex gap-2 pt-2">
                <Button size="sm" variant="outline" @click.stop="openEditModal(habit)">
                  <Edit2 class="h-3.5 w-3.5 mr-1" />
                  Edit
                </Button>
                <Button size="sm" variant="outline" class="text-destructive" @click.stop="handleDeleteHabit(habit.id)">
                  <Trash2 class="h-3.5 w-3.5 mr-1" />
                  Delete
                </Button>
              </div>
            </div>
          </Transition>
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
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden max-h-[85vh] flex flex-col"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60 shrink-0">
              <h2 class="text-lg font-semibold">Create New Habit</h2>
            </div>
            <div class="p-5 space-y-4 overflow-y-auto">
            <div class="p-5 space-y-4 overflow-y-auto">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Name</label>
                <SearchableInput 
                    v-model="newHabit.name" 
                    placeholder="e.g., Morning exercise"
                    :search-function="habitTitleTemplate.search"
                    :on-delete="habitTitleTemplate.deleteTemplate"
                    :show-create-option="true"
                    @create="newHabit.name = $event"
                />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Description (optional)</label>
                <SearchableInput 
                    v-model="newHabit.description" 
                    placeholder="What does this habit involve?"
                    :search-function="habitDescriptionTemplate.search"
                    :on-delete="habitDescriptionTemplate.deleteTemplate"
                    :show-create-option="true"
                    @create="newHabit.description = $event"
                />
              </div>
              
              <!-- Tags with CollapsibleTagManager -->
              <CollapsibleTagManager
                :applied-tag-ids="newHabit.tag_ids"
                :tags="resolveTags(newHabit.tag_ids)"
                :reset-trigger="!showCreateModal"
                @add-tags="(tags) => handleAddTags(newHabit.tag_ids, tags)"
                @remove-tag="(id) => handleRemoveTag(newHabit.tag_ids, id)"
              />

              <!-- Frequency & Color -->
                
                <!-- Selected Tags List -->
                <div class="flex flex-wrap gap-1.5 mb-2" v-if="newHabit.tag_ids.size > 0">
                  <Badge
                    v-for="tag in resolveTags(newHabit.tag_ids)"
                    :key="tag.id"
                    :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                    variant="outline"
                    class="gap-1 pr-1"
                  >
                    <div 
                      class="h-1.5 w-1.5 rounded-full" 
                      :style="{ backgroundColor: tag.color }"
                    />
                    {{ tag.name }}
                    <button
                      type="button"
                      class="ml-0.5 rounded-full hover:bg-black/10 p-0.5"
                      @click="removeTag(newHabit.tag_ids, tag.id)"
                    >
                      <X class="h-3 w-3" />
                    </button>
                  </Badge>
                </div>

                <!-- Collapsed state: click to expand -->
                <div v-if="!isCreateTagsExpanded">
                  <Input 
                    placeholder="Click to manage tags..." 
                    readonly
                    @click="isCreateTagsExpanded = true"
                    class="cursor-pointer"
                  />
                </div>

                <!-- Expanded state: full TagManager -->
                <div v-else>
                  <TagManager
                    mode="select"
                    :embedded="true"
                    :compact="true"
                    v-model:checkedTagIds="tempSelectedTags"
                    class="max-h-[150px] overflow-auto"
                    :applied-tag-ids="newHabit.tag_ids"
                  >
                    <template #actions="{ checkedCount }">
                      <div class="flex gap-2 mb-2">
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          class="h-7 px-2 text-xs flex-1 bg-background"
                          :disabled="checkedCount === 0"
                          @click="addCheckedTags(newHabit.tag_ids)"
                        >
                          <PlusCircle class="h-3 w-3 mr-1" />
                          Add
                        </Button>
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          class="h-7 px-2 text-xs flex-1 bg-background"
                          :disabled="checkedCount === 0"
                          @click="removeCheckedTags(newHabit.tag_ids)"
                        >
                          <MinusCircle class="h-3 w-3 mr-1" />
                          Remove
                        </Button>
                      </div>
                    </template>
                  </TagManager>
                </div>
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Tags</label>
                
                <!-- Selected Tags List -->
                <div class="flex flex-wrap gap-1.5 mb-2" v-if="newHabit.tag_ids.size > 0">
                  <Badge
                    v-for="tag in resolveTags(newHabit.tag_ids)"
                    :key="tag.id"
                    :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                    variant="outline"
                    class="gap-1 pr-1"
                  >
                    <div 
                      class="h-1.5 w-1.5 rounded-full" 
                      :style="{ backgroundColor: tag.color }"
                    />
                    {{ tag.name }}
                    <button
                      type="button"
                      class="ml-0.5 rounded-full hover:bg-black/10 p-0.5"
                      @click="removeTag(newHabit.tag_ids, tag.id)"
                    >
                      <X class="h-3 w-3" />
                    </button>
                  </Badge>
                </div>

                <div class="border border-border rounded-lg p-3 bg-secondary/10">
                  <TagManager
                    mode="select"
                    :embedded="true"
                    :compact="true"
                    v-model:checkedTagIds="tempSelectedTags"
                    class="max-h-[150px] overflow-auto"
                    :applied-tag-ids="newHabit.tag_ids"
                  >
                    <template #actions="{ checkedCount }">
                      <div class="flex gap-2 mb-2">
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          class="h-7 px-2 text-xs flex-1 bg-background"
                          :disabled="checkedCount === 0"
                          @click="addCheckedTags(newHabit.tag_ids)"
                        >
                          <PlusCircle class="h-3 w-3 mr-1" />
                          Add
                        </Button>
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          class="h-7 px-2 text-xs flex-1 bg-background"
                          :disabled="checkedCount === 0"
                          @click="removeCheckedTags(newHabit.tag_ids)"
                        >
                          <MinusCircle class="h-3 w-3 mr-1" />
                          Remove
                        </Button>
                      </div>
                    </template>
                  </TagManager>
                </div>
              </div>

              
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
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
              <div v-if="newHabit.frequency === 'weekly'">>
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
            <div class="px-5 py-4 border-t border-border/60 flex justify-between gap-2 shrink-0">
              <Button variant="ghost" @click="showCreateModal = false">Cancel</Button>
              <Button @click="handleCreateHabit" :disabled="!newHabit.name.trim()">Create</Button>
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
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden max-h-[85vh] flex flex-col"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60 shrink-0">
              <h2 class="text-lg font-semibold">Edit Habit</h2>
            </div>
            <div class="p-5 space-y-4 overflow-y-auto">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Name</label>
                <SearchableInput 
                    v-model="editingHabit.name" 
                    :search-function="habitTitleTemplate.search"
                    :show-create-option="true"
                    @create="editingHabit.name = $event"
                />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Description</label>
                <SearchableInput 
                    :model-value="editingHabit.description ?? ''" 
                    @update:model-value="editingHabit.description = $event || null"
                    :search-function="habitDescriptionTemplate.search"
                    :show-create-option="true"
                    @create="editingHabit.description = $event || null"
                />
              </div>

              <!-- Tags -->
              <div>
                <label class="text-sm font-medium mb-1.5 block">Tags</label>
                
                <!-- Selected Tags List -->
                <div class="flex flex-wrap gap-1.5 mb-2" v-if="editingHabit && editingHabitTagIds.size > 0">
                  <Badge
                    v-for="tag in resolveTags(editingHabitTagIds)"
                    :key="tag.id"
                    :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                    variant="outline"
                    class="gap-1 pr-1"
                  >
                    <div 
                      class="h-1.5 w-1.5 rounded-full" 
                      :style="{ backgroundColor: tag.color }"
                    />
                    {{ tag.name }}
                    <button
                      type="button"
                      class="ml-0.5 rounded-full hover:bg-black/10 p-0.5"
                      @click="removeTag(editingHabitTagIds, tag.id)"
                    >
                      <X class="h-3 w-3" />
                    </button>
                  </Badge>
                </div>

                <!-- Collapsed state: click to expand -->
                <div v-if="!isEditTagsExpanded">
                  <Input 
                    placeholder="Click to manage tags..." 
                    readonly
                    @click="isEditTagsExpanded = true"
                    class="cursor-pointer"
                  />
                </div>

                <!-- Expanded state: full TagManager -->
                <div v-else>
                  <TagManager
                    mode="select"
                    :embedded="true"
                    :compact="true"
                    v-model:checkedTagIds="tempSelectedTags"
                    class="max-h-[150px] overflow-auto"
                    :applied-tag-ids="editingHabitTagIds"
                  >
                    <template #actions="{ checkedCount }">
                      <div class="flex gap-2 mb-2">
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          class="h-7 px-2 text-xs flex-1 bg-background"
                          :disabled="checkedCount === 0"
                          @click="addCheckedTags(editingHabitTagIds)"
                        >
                          <PlusCircle class="h-3 w-3 mr-1" />
                          Add
                        </Button>
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          class="h-7 px-2 text-xs flex-1 bg-background"
                          :disabled="checkedCount === 0"
                          @click="removeCheckedTags(editingHabitTagIds)"
                        >
                          <MinusCircle class="h-3 w-3 mr-1" />
                          Remove
                        </Button>
                      </div>
                    </template>
                  </TagManager>
                </div>
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Tags</label>

                <!-- Selected Tags List -->
                <div class="flex flex-wrap gap-1.5 mb-2" v-if="editingHabit.tag_ids.size > 0">
                  <Badge
                    v-for="tag in resolveTags(editingHabit.tag_ids)"
                    :key="tag.id"
                    :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                    variant="outline"
                    class="gap-1 pr-1"
                  >
                    <div 
                      class="h-1.5 w-1.5 rounded-full" 
                      :style="{ backgroundColor: tag.color }"
                    />
                    {{ tag.name }}
                    <button
                      type="button"
                      class="ml-0.5 rounded-full hover:bg-black/10 p-0.5"
                      @click="removeTag(editingHabit.tag_ids, tag.id)"
                    >
                      <X class="h-3 w-3" />
                    </button>
                  </Badge>
                </div>

                <div class="border border-border rounded-lg p-3 bg-secondary/10">
                  <TagManager
                    mode="select"
                    :embedded="true"
                    :compact="true"
                    v-model:checkedTagIds="tempSelectedTags"
                    class="max-h-[150px] overflow-auto"
                    :applied-tag-ids="editingHabit.tag_ids"
                  >
                    <template #actions="{ checkedCount }">
                      <div class="flex gap-2 mb-2">
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          class="h-7 px-2 text-xs flex-1 bg-background"
                          :disabled="checkedCount === 0"
                          @click="addCheckedTags(editingHabit.tag_ids)"
                        >
                          <PlusCircle class="h-3 w-3 mr-1" />
                          Add
                        </Button>
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          class="h-7 px-2 text-xs flex-1 bg-background"
                          :disabled="checkedCount === 0"
                          @click="removeCheckedTags(editingHabit.tag_ids)"
                        >
                          <MinusCircle class="h-3 w-3 mr-1" />
                          Remove
                        </Button>
                      </div>
                    </template>
                  </TagManager>
                </div>
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
            <div class="px-5 py-4 border-t border-border/60 flex justify-between gap-2 shrink-0">
              <Button variant="ghost" @click="showEditModal = false">Cancel</Button>
              <Button @click="handleUpdateHabit">Save Changes</Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

