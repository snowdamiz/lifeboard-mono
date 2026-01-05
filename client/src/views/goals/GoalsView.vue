<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { format } from 'date-fns'
import { 
  Target, Plus, ChevronRight, Calendar, CheckCircle2, Circle, 
  Trash2, Edit2, MoreVertical, Trophy, Flag, Settings2, Tags, 
  Filter, ArrowUpDown, X
} from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import TagSelector from '@/components/shared/TagSelector.vue'
import { useGoalsStore } from '@/stores/goals'
import type { Goal, Tag, GoalCategory } from '@/types'

const goalsStore = useGoalsStore()

const showCreateModal = ref(false)
const showEditModal = ref(false)
const showCategoryModal = ref(false)
const editingGoal = ref<Goal | null>(null)
const editingGoalTags = ref<Tag[]>([])

const newGoal = ref({
  title: '',
  description: '',
  target_date: '',
  goal_category_id: '',
  tags: [] as Tag[]
})

const newCategory = ref({
  name: '',
  color: '#6366f1',
  parent_id: ''
})

// Fallback categories for when no custom categories exist
const defaultCategories = ['Personal', 'Career', 'Health', 'Finance', 'Learning', 'Relationships']

// Build category options for select
const categoryOptions = computed(() => {
  const options = [{ value: '', label: 'Select category' }]
  
  if (goalsStore.categories.length === 0) {
    // Use default categories as strings (legacy support)
    defaultCategories.forEach(cat => options.push({ value: cat, label: cat }))
  } else {
    // Use custom categories
    goalsStore.flatCategories.forEach(cat => {
      const label = cat.isSubcategory ? `  └ ${cat.name}` : cat.name
      options.push({ value: cat.id, label })
    })
  }
  
  return options
})

const activeTab = ref<'active' | 'completed'>('active')

// Filtering and sorting
const filterCategory = ref('')
const filterTags = ref<Tag[]>([])
const sortBy = ref<'date' | 'progress' | 'title' | 'category'>('date')
const sortOrder = ref<'asc' | 'desc'>('asc')

const displayedGoals = computed(() => {
  let goals = activeTab.value === 'active' ? goalsStore.activeGoals : goalsStore.completedGoals
  
  // Filter by category
  if (filterCategory.value) {
    goals = goals.filter(g => 
      g.goal_category_id === filterCategory.value || 
      g.category === filterCategory.value ||
      g.goal_category?.parent?.id === filterCategory.value
    )
  }
  
  // Filter by tags
  if (filterTags.value.length > 0) {
    const tagIds = filterTags.value.map(t => t.id)
    goals = goals.filter(g => 
      g.tags && g.tags.some(t => tagIds.includes(t.id))
    )
  }
  
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
        comparison = a.progress - b.progress
        break
      case 'title':
        comparison = a.title.localeCompare(b.title)
        break
      case 'category':
        const catA = getCategoryDisplay(a) || ''
        const catB = getCategoryDisplay(b) || ''
        comparison = catA.localeCompare(catB)
        break
    }
    
    return sortOrder.value === 'desc' ? -comparison : comparison
  })
  
  return goals
})

const clearFilters = () => {
  filterCategory.value = ''
  filterTags.value = []
}

const hasActiveFilters = computed(() => filterCategory.value || filterTags.value.length > 0)

onMounted(async () => {
  await Promise.all([
    goalsStore.fetchGoals(),
    goalsStore.fetchCategories()
  ])
})

const handleCreateGoal = async () => {
  if (!newGoal.value.title.trim()) return
  
  const goalData: Partial<Goal> = {
    title: newGoal.value.title,
    description: newGoal.value.description || null,
    target_date: newGoal.value.target_date || null,
    status: 'not_started'
  }
  
  // Handle category - could be UUID (new) or string (legacy)
  if (newGoal.value.goal_category_id) {
    // Check if it's a valid UUID or legacy category name
    if (newGoal.value.goal_category_id.includes('-')) {
      goalData.goal_category_id = newGoal.value.goal_category_id
    } else {
      goalData.category = newGoal.value.goal_category_id
    }
  }
  
  const goal = await goalsStore.createGoal(goalData)
  
  // Update tags if any selected
  if (newGoal.value.tags.length > 0) {
    await goalsStore.updateGoalTags(goal.id, newGoal.value.tags.map(t => t.id))
  }
  
  newGoal.value = { title: '', description: '', target_date: '', goal_category_id: '', tags: [] }
  showCreateModal.value = false
}

const handleUpdateGoal = async () => {
  if (!editingGoal.value) return
  
  const goalData: Partial<Goal> = {
    title: editingGoal.value.title,
    description: editingGoal.value.description,
    target_date: editingGoal.value.target_date,
    status: editingGoal.value.status
  }
  
  // Handle category
  if (editingGoal.value.goal_category_id) {
    goalData.goal_category_id = editingGoal.value.goal_category_id
  } else if (editingGoal.value.category) {
    goalData.category = editingGoal.value.category
  }
  
  await goalsStore.updateGoal(editingGoal.value.id, goalData)
  
  // Update tags
  await goalsStore.updateGoalTags(editingGoal.value.id, editingGoalTags.value.map(t => t.id))
  
  showEditModal.value = false
  editingGoal.value = null
  editingGoalTags.value = []
}

const handleDeleteGoal = async (id: string) => {
  if (confirm('Are you sure you want to delete this goal?')) {
    await goalsStore.deleteGoal(id)
  }
}

const openEditModal = (goal: Goal) => {
  editingGoal.value = { ...goal }
  editingGoalTags.value = [...(goal.tags || [])]
  showEditModal.value = true
}

const handleCreateCategory = async () => {
  if (!newCategory.value.name.trim()) return
  
  await goalsStore.createCategory({
    name: newCategory.value.name,
    color: newCategory.value.color,
    parent_id: newCategory.value.parent_id || null
  })
  
  newCategory.value = { name: '', color: '#6366f1', parent_id: '' }
}

const handleDeleteCategory = async (id: string) => {
  if (confirm('Delete this category? Goals using it will be uncategorized.')) {
    await goalsStore.deleteCategory(id)
  }
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

const getCategoryDisplay = (goal: Goal) => {
  if (goal.goal_category) {
    if (goal.goal_category.parent) {
      return `${goal.goal_category.parent.name} / ${goal.goal_category.name}`
    }
    return goal.goal_category.name
  }
  return goal.category
}
</script>

<template>
  <div class="space-y-4 sm:space-y-6 animate-fade-in">
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
        <Button variant="outline" size="icon" @click="showCategoryModal = true" title="Manage Categories">
          <Settings2 class="h-4 w-4" />
        </Button>
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
        <!-- Category Filter -->
        <Select 
          v-model="filterCategory"
          :options="[
            { value: '', label: 'All Categories' },
            ...categoryOptions.slice(1)
          ]"
          class="w-40 text-xs"
        />
        
        <!-- Sort -->
        <Select 
          v-model="sortBy"
          :options="[
            { value: 'date', label: 'Sort by Date' },
            { value: 'progress', label: 'Sort by Progress' },
            { value: 'title', label: 'Sort by Title' },
            { value: 'category', label: 'Sort by Category' }
          ]"
          class="w-36 text-xs"
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
        
        <Button 
          v-if="hasActiveFilters"
          variant="ghost" 
          size="sm"
          class="h-8 text-xs"
          @click="clearFilters"
        >
          <X class="h-3 w-3 mr-1" />
          Clear
        </Button>
      </div>
    </div>

    <!-- Tag Filter -->
    <div class="flex items-center gap-2">
      <Filter class="h-4 w-4 text-muted-foreground" />
      <span class="text-sm text-muted-foreground">Filter by tags:</span>
      <TagSelector v-model="filterTags" class="flex-1" />
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
      <p class="text-muted-foreground mt-1">{{ activeTab === 'active' ? 'Create a goal to start tracking your progress' : 'Complete some goals to see them here' }}</p>
      <Button v-if="activeTab === 'active'" variant="outline" class="mt-4" @click="showCreateModal = true">
        <Plus class="h-4 w-4 mr-1.5" />
        Create your first goal
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
                <span v-if="getCategoryDisplay(goal)" class="flex items-center gap-1">
                  <Flag class="h-3 w-3" />
                  {{ getCategoryDisplay(goal) }}
                </span>
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
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Create New Goal</h2>
            </div>
            <div class="p-5 space-y-4">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Title</label>
                <Input v-model="newGoal.title" placeholder="What do you want to achieve?" />
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
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Category</label>
                  <Select 
                    v-model="newGoal.goal_category_id"
                    :options="categoryOptions"
                    placeholder="Select category"
                  />
                </div>
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Target Date</label>
                  <Input v-model="newGoal.target_date" type="date" />
                </div>
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Tags</label>
                <TagSelector v-model="newGoal.tags" />
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showCreateModal = false">Cancel</Button>
              <Button @click="handleCreateGoal" :disabled="!newGoal.title.trim()">Create Goal</Button>
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
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Edit Goal</h2>
            </div>
            <div class="p-5 space-y-4">
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
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Category</label>
                  <Select 
                    :model-value="editingGoal.goal_category_id ?? editingGoal.category ?? ''"
                    @update:model-value="editingGoal.goal_category_id = String($event) || null; editingGoal.category = null"
                    :options="categoryOptions"
                    placeholder="Select category"
                  />
                </div>
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Target Date</label>
                  <Input :model-value="editingGoal.target_date ?? ''" @update:model-value="editingGoal.target_date = String($event) || null" type="date" />
                </div>
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Tags</label>
                <TagSelector v-model="editingGoalTags" />
              </div>
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

    <!-- Category Management Modal -->
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
          v-if="showCategoryModal"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          @click="showCategoryModal = false"
        >
          <div 
            class="w-full max-w-lg bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Manage Categories</h2>
              <p class="text-sm text-muted-foreground mt-0.5">Create and organize your goal categories</p>
            </div>
            <div class="p-5 space-y-4 max-h-[60vh] overflow-auto">
              <!-- Add new category -->
              <div class="p-3 bg-secondary/50 rounded-lg space-y-3">
                <h3 class="text-sm font-medium">Add Category</h3>
                <div class="flex gap-2">
                  <Input 
                    v-model="newCategory.name" 
                    placeholder="Category name"
                    class="flex-1"
                  />
                  <input 
                    type="color" 
                    v-model="newCategory.color"
                    class="w-10 h-9 rounded-md border border-input cursor-pointer"
                  />
                  <Button size="sm" @click="handleCreateCategory" :disabled="!newCategory.name.trim()">
                    <Plus class="h-4 w-4" />
                  </Button>
                </div>
                <div v-if="goalsStore.categories.length > 0">
                  <label class="text-xs text-muted-foreground">Parent (optional - for subcategory)</label>
                  <Select 
                    v-model="newCategory.parent_id"
                    :options="[
                      { value: '', label: 'None (top level)' },
                      ...goalsStore.categories.map(c => ({ value: c.id, label: c.name }))
                    ]"
                    class="mt-1"
                  />
                </div>
              </div>
              
              <!-- Existing categories -->
              <div v-if="goalsStore.categories.length === 0" class="text-center py-8 text-muted-foreground">
                <Flag class="h-8 w-8 mx-auto mb-2 opacity-50" />
                <p class="text-sm">No custom categories yet</p>
              </div>
              <div v-else class="space-y-2">
                <div 
                  v-for="category in goalsStore.categories" 
                  :key="category.id"
                  class="border border-border rounded-lg overflow-hidden"
                >
                  <div class="flex items-center gap-3 p-3 bg-card">
                    <div 
                      class="w-4 h-4 rounded-full shrink-0"
                      :style="{ backgroundColor: category.color }"
                    />
                    <span class="flex-1 font-medium">{{ category.name }}</span>
                    <Button 
                      variant="ghost" 
                      size="icon" 
                      class="h-7 w-7 text-destructive"
                      @click="handleDeleteCategory(category.id)"
                    >
                      <Trash2 class="h-3.5 w-3.5" />
                    </Button>
                  </div>
                  <!-- Subcategories -->
                  <div v-if="category.subcategories && category.subcategories.length > 0" class="bg-secondary/30">
                    <div 
                      v-for="sub in category.subcategories" 
                      :key="sub.id"
                      class="flex items-center gap-3 p-2 pl-8 border-t border-border/50"
                    >
                      <div 
                        class="w-3 h-3 rounded-full shrink-0"
                        :style="{ backgroundColor: sub.color }"
                      />
                      <span class="flex-1 text-sm">{{ sub.name }}</span>
                      <Button 
                        variant="ghost" 
                        size="icon" 
                        class="h-6 w-6 text-destructive"
                        @click="handleDeleteCategory(sub.id)"
                      >
                        <Trash2 class="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end">
              <Button variant="ghost" @click="showCategoryModal = false">Close</Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

