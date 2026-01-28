<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { format } from 'date-fns'
import { 
  Target, Plus, ChevronRight, Calendar, CheckCircle2, Circle, 
  Trash2, Edit2, Trophy, Flag, Settings2, Tags, 
  Filter, ArrowUpDown, X, PlusCircle, MinusCircle
} from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import { Checkbox } from '@/components/ui/checkbox'
import TagManager from '@/components/shared/TagManager.vue'
import CollapsibleTagManager from '@/components/shared/CollapsibleTagManager.vue'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import { useGoalsStore } from '@/stores/goals'
import { useTagsStore } from '@/stores/tags'
import type { Goal, Tag } from '@/types'

const goalsStore = useGoalsStore()
const tagsStore = useTagsStore()

const showCreateModal = ref(false)
const showEditModal = ref(false)
const showCategoryModal = ref(false)
const editingGoal = ref<Goal | null>(null)
// TagManager expects Set<string>
const editingGoalTagIds = ref<Set<string>>(new Set())

const newGoal = ref({
  title: '',
  description: '',
  target_date: '',
  tag_ids: new Set<string>()
})

// Tag selection state - handled by CollapsibleTagManager component now

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

// Milestones state
const newGoalMilestones = ref<Array<{ title: string; completed: boolean }>>([])
const editingGoalMilestones = ref<Array<{ id?: string; title: string; completed: boolean; position: number; completed_at?: string | null }>>([])
const newMilestoneInput = ref('')
const editMilestoneInput = ref('')

const addMilestone = (isEditing: boolean) => {
  if (isEditing) {
    if (!editMilestoneInput.value.trim()) return
    
    // Save as template for future reuse
    goalsStore.saveMilestone(editMilestoneInput.value)

    editingGoalMilestones.value.push({
      title: editMilestoneInput.value,
      completed: false,
      position: editingGoalMilestones.value.length
    })
    editMilestoneInput.value = ''
  } else {
    if (!newMilestoneInput.value.trim()) return

    // Save as template for future reuse
    goalsStore.saveMilestone(newMilestoneInput.value)

    newGoalMilestones.value.push({
      title: newMilestoneInput.value,
      completed: false
    })
    newMilestoneInput.value = ''
  }
}

const removeMilestone = (index: number, isEditing: boolean) => {
  if (isEditing) {
    editingGoalMilestones.value.splice(index, 1)
  } else {
    newGoalMilestones.value.splice(index, 1)
  }
}

const activeTab = ref<'active' | 'completed'>('active')

// Filtering and sorting
const isFilterOpen = ref(false)
const filterCheckedTagIds = ref<Set<string>>(new Set())

// Sync filter tags from store to local state when store changes
watch(() => goalsStore.filterTags, (newTags) => {
  filterCheckedTagIds.value = new Set(newTags)
}, { immediate: true })

const activeFilterCount = computed(() => goalsStore.filterTags.length)
const sortBy = ref<'date' | 'progress' | 'title' | 'category'>('date')
const sortOrder = ref<'asc' | 'desc'>('asc')

const toggleFilterTag = (tagId: string) => {
  const index = goalsStore.filterTags.indexOf(tagId)
  if (index === -1) {
    goalsStore.filterTags.push(tagId)
  } else {
    goalsStore.filterTags.splice(index, 1)
  }
}

const applyFilters = () => {
  goalsStore.filterTags = Array.from(filterCheckedTagIds.value)
  goalsStore.fetchGoals()
  isFilterOpen.value = false
}

const clearFilters = () => {
  goalsStore.filterTags = []
  goalsStore.fetchGoals()
  isFilterOpen.value = false
}

const displayedGoals = computed(() => {
  // Goals are already filtered by backend (fetchGoals called on mount and filter apply)
  let goals = activeTab.value === 'active' ? goalsStore.activeGoals : goalsStore.completedGoals
  
  // Sort
  goals = [...goals].sort((a, b) => {
    let comparison = 0
    
    switch (sortBy.value) {
      case 'date':
        const dateA = a.target_date ? new Date(a.target_date).getTime() : Infinity
        const dateB = b.target_date ? new Date(b.target_date).getTime() : Infinity
        comparison = dateA - dateB
        break
      case 'progress':
        comparison = (a.progress || 0) - (b.progress || 0)
        if (comparison === 0) {
          const statusPriority: Record<string, number> = {
            'completed': 3,
            'in_progress': 2,
            'not_started': 1,
            'abandoned': 0
          }
          const statusA = statusPriority[a.status] || 0
          const statusB = statusPriority[b.status] || 0
          comparison = statusA - statusB
        }
        break
      case 'title':
        comparison = a.title.localeCompare(b.title)
        break
    }
    
    return sortOrder.value === 'desc' ? -comparison : comparison
  })
  
  return goals
})

onMounted(async () => {
  // Reset filters
  goalsStore.filterTags = []
  await goalsStore.fetchGoals()
})

const handleCreateGoal = async () => {
  if (!newGoal.value.title.trim()) return
  
  const goalData: Partial<Goal> = {
    title: newGoal.value.title,
    description: newGoal.value.description || null,
    target_date: newGoal.value.target_date || null,
    status: 'not_started',
    milestones: newGoalMilestones.value.map((m, index) => ({
      ...m,
      position: index,
      id: undefined as unknown as string, // Type hack, backend will generate
      completed_at: m.completed ? new Date().toISOString() : null
    }))
  }
  
  const goal = await goalsStore.createGoal(goalData)
  
  // Update tags if any selected
  if (newGoal.value.tag_ids.size > 0) {
    await goalsStore.updateGoalTags(goal.id, Array.from(newGoal.value.tag_ids))
  }
  
  newGoal.value = { title: '', description: '', target_date: '', tag_ids: new Set() }
  newGoalMilestones.value = []
  newMilestoneInput.value = ''
  showCreateModal.value = false
}

watch(showCreateModal, (val) => {
  // CollapsibleTagManager handles its own reset
})

watch(showEditModal, (val) => {
  // CollapsibleTagManager handles its own reset
})

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

const handleUpdateGoal = async () => {
  if (!editingGoal.value) return
  
  const goalData: Partial<Goal> = {
    title: editingGoal.value.title,
    description: editingGoal.value.description,
    target_date: editingGoal.value.target_date,
    status: editingGoal.value.status,
    milestones: editingGoalMilestones.value.map((m, index) => ({
      ...m,
      position: index,
      id: m.id || undefined as unknown as string,
      completed_at: m.completed ? (m.completed_at || new Date().toISOString()) : null
    }))
  }
  
  await goalsStore.updateGoal(editingGoal.value.id, goalData)
  
  // Update tags
  await goalsStore.updateGoalTags(editingGoal.value.id, Array.from(editingGoalTagIds.value))
  
  showEditModal.value = false
  editingGoal.value = null
  editingGoalTagIds.value = new Set()
  editingGoalMilestones.value = []
  editMilestoneInput.value = ''
}

watch(showEditModal, (val) => {
  // CollapsibleTagManager handles its own reset
})

const handleDeleteGoal = async (id: string) => {
  await goalsStore.deleteGoal(id)
}

const openEditModal = (goal: Goal) => {
  editingGoal.value = { ...goal }
  editingGoalTagIds.value = new Set(goal.tags ? goal.tags.map(t => t.id) : [])
  editingGoalMilestones.value = goal.milestones 
    ? [...goal.milestones].sort((a, b) => a.position - b.position)
    : []
  showEditModal.value = true
}

</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in pb-20 sm:pb-0">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Target class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Goals</h1>
          <p class="text-sm text-muted-foreground">Track your long-term goals and milestones</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <Button @click="showCreateModal = true">
          <Plus class="h-4 w-4 mr-1.5" />
          New Goal
        </Button>
      </div>
    </div>

    <!-- Tabs and Filters -->
    <div class="flex flex-col sm:flex-row sm:items-center gap-3 sm:gap-4">
      <!-- Tabs -->
      <div class="flex gap-1 p-1 bg-secondary/50 rounded-lg w-fit">
        <button
          :class="[
            'px-4 py-1.5 rounded-md text-sm font-medium transition-all',
            activeTab === 'active' 
              ? 'bg-background shadow-sm text-foreground' 
              : 'text-muted-foreground hover:text-foreground'
          ]"
          @click="activeTab = 'active'"
        >
          Active ({{ goalsStore.activeGoals.length }})
        </button>
        <button
          :class="[
            'px-4 py-1.5 rounded-md text-sm font-medium transition-all',
            activeTab === 'completed' 
              ? 'bg-background shadow-sm text-foreground' 
              : 'text-muted-foreground hover:text-foreground'
          ]"
          @click="activeTab = 'completed'"
        >
          Completed ({{ goalsStore.completedGoals.length }})
        </button>
      </div>

      <div class="flex-1" />

      <!-- Filter & Sort Controls -->
      <div class="flex flex-wrap items-center gap-2">
        <!-- Sort -->
        <Select 
          v-model="sortBy"
          :options="[
            { value: 'date', label: 'Sort by Date' },
            { value: 'progress', label: 'Sort by Progress' },
            { value: 'title', label: 'Sort by Title' }
          ]"
          class="w-[160px] text-xs"
        />
        
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-8 w-8"
          @click="sortOrder = sortOrder === 'asc' ? 'desc' : 'asc'"
          :title="sortOrder === 'asc' ? 'Ascending' : 'Descending'"
        >
          <ArrowUpDown class="h-4 w-4" :class="sortOrder === 'desc' && 'rotate-180'" />
        </Button>

        <!-- Filter Button -->
        <div class="relative">
          <Button 
            :variant="activeFilterCount > 0 ? 'default' : 'outline'" 
            size="sm" 
            class="h-9 gap-2"
            @click="isFilterOpen = !isFilterOpen"
          >
            <Filter class="h-4 w-4" />
            <span class="hidden sm:inline">Filter</span>
            <Badge v-if="activeFilterCount > 0" variant="secondary" class="ml-0.5 h-5 px-1.5 min-w-[20px] justify-center bg-background/20 text-current border-0">
              {{ activeFilterCount }}
            </Badge>
          </Button>

          <!-- Filter Dropdown -->
          <div
            v-if="isFilterOpen"
            class="absolute top-full right-0 mt-2 w-80 bg-card border border-border rounded-xl shadow-xl z-50 overflow-hidden"
          >
            <div class="p-3 border-b border-border bg-secondary/30 flex items-center justify-between">
               <span class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Filter by Tags</span>
               <button class="text-xs text-primary hover:underline" @click="clearFilters" v-if="activeFilterCount > 0">
                Clear all
              </button>
            </div>
            
             <div class="p-2">
              <TagManager
                v-model:checkedTagIds="filterCheckedTagIds"
                mode="select"
                embedded
                :rows="3"
              />
            </div>
             <div class="p-3 border-t bg-muted/20 flex justify-between gap-2">
              <Button variant="ghost" size="sm" @click="clearFilters" :disabled="activeFilterCount === 0">
                Clear
              </Button>
              <Button size="sm" @click="applyFilters">
                Apply
              </Button>
            </div>
          </div>
          <!-- Backdrop to close -->
          <div v-if="isFilterOpen" class="fixed inset-0 z-40 bg-transparent" @click="isFilterOpen = false" />
        </div>
      </div>
    </div>
    
    <!-- Active Filters Display -->
    <div v-if="activeFilterCount > 0" class="flex flex-wrap gap-2 items-center">
      <span class="text-xs text-muted-foreground">Active filters:</span>
      <Badge 
        v-for="tagId in goalsStore.filterTags" 
        :key="tagId"
        variant="secondary"
        class="gap-1 pl-2 pr-1 py-0.5"
      >
        <span class="truncate max-w-[100px]">Tag selected</span>
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-3 w-3 sm:h-4 sm:w-4 ml-1 rounded-full -mr-0.5 hover:bg-transparent hover:text-destructive"
          @click.stop="toggleFilterTag(tagId); applyFilters()"
        >
          <X class="h-2 w-2 sm:h-3 sm:w-3" />
        </Button>
      </Badge>
      <Button variant="link" size="sm" class="h-auto p-0 text-xs text-muted-foreground" @click="clearFilters">
        Clear all
      </Button>
    </div>

    <!-- Goals List -->
    <div v-if="goalsStore.loading" class="flex items-center justify-center py-12">
      <div class="h-6 w-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
    </div>

    <div v-else-if="displayedGoals.length === 0" class="text-center py-16">
      <div class="h-16 w-16 rounded-2xl bg-primary/5 mx-auto mb-4 flex items-center justify-center">
        <Trophy class="h-8 w-8 text-primary/60" />
      </div>
      <h3 class="font-semibold text-lg">{{ activeTab === 'active' ? 'No active goals' : 'No completed goals yet' }}</h3>
      <p class="text-muted-foreground mt-1">
         {{ activeFilterCount > 0 ? "Try adjusting your filters" : (activeTab === 'active' ? 'Create a goal to start tracking your progress' : 'Complete some goals to see them here') }}
      </p>
      <Button v-if="activeTab === 'active' || activeFilterCount > 0" variant="outline" class="mt-4" @click="activeFilterCount > 0 ? clearFilters() : (showCreateModal = true)">
        <component :is="activeFilterCount > 0 ? X : Plus" class="h-4 w-4 mr-1.5" />
        {{ activeFilterCount > 0 ? "Clear Filters" : "Create your first goal" }}
      </Button>
    </div>

    <div v-else class="grid gap-4">
      <Card 
        v-for="goal in displayedGoals" 
        :key="goal.id" 
        class="group hover:shadow-md transition-all cursor-pointer"
        @click="$router.push(`/goals/${goal.id}`)"
      >
        <CardContent class="p-4 sm:p-5">
          <div class="flex items-start gap-4">
            <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
              <Target class="h-5 w-5 text-primary" />
            </div>
            
            <div class="flex-1 min-w-0">
              <div class="flex items-start justify-between gap-2">
                <div>
                  <h3 class="font-semibold text-base truncate">{{ goal.title }}</h3>
                  <p v-if="goal.description" class="text-sm text-muted-foreground line-clamp-1 mt-0.5">{{ goal.description }}</p>
                </div>
                <Badge :class="getStatusColor(goal.status)" class="shrink-0">
                  {{ goal.status.replace('_', ' ') }}
                </Badge>
              </div>
              
              <!-- Progress Bar -->
              <div class="mt-3">
                <div class="flex items-center justify-between text-xs mb-1.5">
                  <span class="text-muted-foreground">Progress</span>
                  <span class="font-medium">{{ goal.progress }}%</span>
                </div>
                <div class="h-2 bg-secondary rounded-full overflow-hidden">
                  <div 
                    :class="['h-full rounded-full transition-all duration-500', getProgressColor(goal.progress)]"
                    :style="{ width: `${goal.progress}%` }"
                  />
                </div>
              </div>
              
              <!-- Meta info -->
              <div class="flex items-center flex-wrap gap-x-4 gap-y-2 mt-3 text-xs text-muted-foreground">

                <span v-if="goal.target_date" class="flex items-center gap-1">
                  <Calendar class="h-3 w-3" />
                  {{ format(new Date(goal.target_date), 'MMM d, yyyy') }}
                </span>
                <span class="flex items-center gap-1">
                  <CheckCircle2 class="h-3 w-3" />
                  {{ goal.milestones.filter(m => m.completed).length }}/{{ goal.milestones.length }} milestones
                </span>
              </div>
              <!-- Tags -->
              <div v-if="goal.tags && goal.tags.length > 0" class="flex items-center gap-1.5 mt-2">
                <Tags class="h-3 w-3 text-muted-foreground" />
                <div class="flex flex-wrap gap-1">
                  <Badge 
                    v-for="tag in goal.tags" 
                    :key="tag.id" 
                    variant="outline"
                    class="text-[10px] px-1.5 py-0"
                    :style="{ borderColor: tag.color, color: tag.color }"
                  >
                    {{ tag.name }}
                  </Badge>
                </div>
              </div>
            </div>

            <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 text-muted-foreground"
                @click.stop="openEditModal(goal)"
              >
                <Edit2 class="h-4 w-4" />
              </Button>
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 text-destructive"
                @click.stop="handleDeleteGoal(goal.id)"
              >
                <Trash2 class="h-4 w-4" />
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Create Goal Modal -->
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
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-visible flex flex-col"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60 flex items-center justify-between shrink-0">
              <h2 class="text-lg font-semibold">Create New Goal</h2>
              <Button variant="ghost" size="icon" @click="showCreateModal = false">
                <X class="h-4 w-4" />
              </Button>
            </div>
            <div class="p-5 space-y-4 flex-1 overflow-y-auto">
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div class="sm:col-span-2">
                  <label class="text-sm font-medium mb-1.5 block">Title</label>
                  <SearchableInput 
                    v-model="newGoal.title" 
                    :search-function="goalsStore.searchTitles"
                    placeholder="What do you want to achieve?" 
                  />
                </div>
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Target Date</label>
                  <Input v-model="newGoal.target_date" type="date" />
                </div>
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Description</label>
                <textarea 
                  v-model="newGoal.description"
                  class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm resize-none focus:outline-none focus:ring-2 focus:ring-ring/50"
                  rows="3"
                  placeholder="Describe your goal in detail..."
                />
              </div>

              <!-- Milestones and Tags in 2 columns -->
              <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <!-- Milestones -->
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Milestones</label>
                  <div class="space-y-2">
                    <div
                      v-for="(milestone, index) in newGoalMilestones"
                      :key="index"
                      class="flex items-center gap-2 p-2 bg-secondary/40 rounded-lg"
                    >
                      <Checkbox v-model="milestone.completed" class="shrink-0" />
                      <Input v-model="milestone.title" class="flex-1 h-8 bg-transparent border-0 focus-visible:ring-0 px-1" />
                      <Button variant="ghost" size="icon" class="h-7 w-7 shrink-0" @click="removeMilestone(index, false)">
                        <Trash2 class="h-3.5 w-3.5 text-destructive" />
                      </Button>
                    </div>

                    <div class="flex items-center gap-2">
                      <Plus class="h-4 w-4 text-muted-foreground shrink-0" />
                      <SearchableInput 
                        v-model="newMilestoneInput" 
                        :search-function="goalsStore.searchMilestones"
                        placeholder="Add a milestone..."
                        class="flex-1"
                        @select="() => addMilestone(false)"
                        @keydown.enter.prevent="addMilestone(false)"
                      />
                    </div>
                  </div>
                </div>

                <!-- Tags with CollapsibleTagManager -->
                <CollapsibleTagManager
                  :applied-tag-ids="newGoal.tag_ids"
                  :tags="resolveTags(newGoal.tag_ids)"
                  :reset-trigger="!showCreateModal"
                  @add-tags="(tags) => handleAddTags(newGoal.tag_ids, tags)"
                  @remove-tag="(id) => handleRemoveTag(newGoal.tag_ids, id)"
                />
              <!-- End of Tags column -->
            </div>
            <!-- End of Milestones and Tags grid -->
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showCreateModal = false">Cancel</Button>
              <Button @click="handleCreateGoal" :disabled="!newGoal.title.trim()">Create</Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Edit Goal Modal -->
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
          v-if="showEditModal && editingGoal"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          @click="showEditModal = false"
        >
          <div 
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden max-h-[90vh] flex flex-col"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60 flex items-center justify-between shrink-0">
              <h2 class="text-lg font-semibold">Edit Goal</h2>
              <Button variant="ghost" size="icon" @click="showEditModal = false">
                <X class="h-4 w-4" />
              </Button>
            </div>
            <div class="p-5 space-y-4 flex-1 overflow-y-auto">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Title</label>
                <Input v-model="editingGoal.title" />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Description</label>
                <textarea 
                  v-model="editingGoal.description"
                  class="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm resize-none focus:outline-none focus:ring-2 focus:ring-ring/50"
                  rows="3"
                />
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div class="col-span-2">
                  <label class="text-sm font-medium mb-1.5 block">Target Date</label>
                  <Input :model-value="editingGoal.target_date ?? ''" @update:model-value="editingGoal.target_date = String($event) || null" type="date" />
                </div>
              </div>

              <!-- Milestones -->
              <div>
                <label class="text-sm font-medium mb-1.5 block">Milestones</label>
                <div class="space-y-2">
                  <div
                    v-for="(milestone, index) in editingGoalMilestones"
                    :key="milestone.id || index"
                    class="flex items-center gap-2 p-2 bg-secondary/40 rounded-lg"
                  >
                    <Checkbox v-model="milestone.completed" class="shrink-0" />
                    <Input v-model="milestone.title" class="flex-1 h-8 bg-transparent border-0 focus-visible:ring-0 px-1" />
                    <Button variant="ghost" size="icon" class="h-7 w-7 shrink-0" @click="removeMilestone(index, true)">
                      <Trash2 class="h-3.5 w-3.5 text-destructive" />
                    </Button>
                  </div>

                  <div class="flex items-center gap-2">
                    <Plus class="h-4 w-4 text-muted-foreground shrink-0" />
                    <SearchableInput 
                      v-model="editMilestoneInput" 
                      :search-function="goalsStore.searchMilestones"
                      placeholder="Add a milestone..."
                      class="flex-1"
                      @select="() => addMilestone(true)"
                      @keydown.enter.prevent="addMilestone(true)"
                    />
                  </div>
                </div>
              </div>
              <!-- Tags with CollapsibleTagManager -->
              <CollapsibleTagManager
                :applied-tag-ids="editingGoalTagIds"
                :tags="resolveTags(editingGoalTagIds)"
                :reset-trigger="!showEditModal"
                @add-tags="(tags) => handleAddTags(editingGoalTagIds, tags)"
                @remove-tag="(id) => handleRemoveTag(editingGoalTagIds, id)"
              />
              <div>
                <label class="text-sm font-medium mb-1.5 block">Status</label>
                <Select 
                  v-model="editingGoal.status"
                  :options="[
                    { value: 'not_started', label: 'Not Started' },
                    { value: 'in_progress', label: 'In Progress' },
                    { value: 'completed', label: 'Completed' },
                    { value: 'abandoned', label: 'Abandoned' }
                  ]"
                  placeholder="Select status"
                />
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showEditModal = false">Cancel</Button>
              <Button @click="handleUpdateGoal">Save Changes</Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

