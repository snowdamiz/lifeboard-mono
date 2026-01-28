<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { format, subDays, eachDayOfInterval, isSameDay, startOfWeek, endOfWeek } from 'date-fns'
import { 
  Flame, Plus, CheckCircle2, Circle, Trash2, Edit2, Trophy, Zap, Calendar, Filter,
  PlusCircle, MinusCircle, X, Ban
} from 'lucide-vue-next'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import TagManager from '@/components/shared/TagManager.vue'
import CollapsibleTagManager from '@/components/shared/CollapsibleTagManager.vue'
import HabitCalendarView from '@/components/calendar/HabitCalendarView.vue'
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
const showSkipModal = ref(false)
const showManageInventoriesModal = ref(false)
const newInventoryName = ref('')
const newInventoryColor = ref('#10b981')
const editingInventoryColorId = ref<string | null>(null)

type EditingHabit = Omit<HabitWithStatus, 'scheduled_time' | 'duration_minutes' | 'inventory_id' | 'days_of_week'> & {
  scheduled_time: string | undefined
  duration_minutes: number | undefined
  inventory_id: string | undefined
  days_of_week: number[] | null
  tag_ids: Set<string>
}

const editingHabit = ref<EditingHabit | null>(null)
const skippingHabit = ref<HabitWithStatus | null>(null)
const skipReason = ref('')


// Tab navigation
const activeTab = ref<'inventory' | 'calendar'>('inventory')

const newHabit = ref({
  name: '',
  description: '',
  frequency: 'daily',
  color: '#10b981',
  days_of_week: [] as number[],
  scheduled_time: undefined as string | undefined,
  duration_minutes: undefined as number | undefined,
  is_start_of_day: false,
  inventory_id: undefined as string | undefined,
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

// Sorting by tag
const sortByTag = ref(false)

// Helper to parse time string (HH:MM) to minutes since midnight
const timeToMinutes = (timeStr: string | null): number => {
  if (!timeStr) return 9999 // Put unscheduled habits at the end
  const [hours, minutes] = timeStr.split(':').map(Number)
  return hours * 60 + minutes
}

const sortedHabits = computed(() => {
  const habitsList = [...habitsStore.habits]
  
  // Sort: Start of Day first, then by scheduled time (earliest at top)
  habitsList.sort((a, b) => {
    // Start of Day habits always come first
    if (a.is_start_of_day && !b.is_start_of_day) return -1
    if (!a.is_start_of_day && b.is_start_of_day) return 1
    
    // Then sort by time
    const timeA = timeToMinutes(a.scheduled_time)
    const timeB = timeToMinutes(b.scheduled_time)
    return timeA - timeB
  })
  
  // If sorting by tag, apply secondary sort within same groups
  if (sortByTag.value) {
    habitsList.sort((a, b) => {
      const aTag = a.tags?.[0]?.name || 'zzz'
      const bTag = b.tags?.[0]?.name || 'zzz'
      return aTag.localeCompare(bTag)
    })
  }
  
  return habitsList
})

// Organize habits by inventory for side-by-side display
const inventoriesWithHabits = computed(() => {
  // Helper to sort habits with start-of-day awareness
  const sortHabits = (habits: typeof habitsStore.habits) => {
    // Find the start of day time (or default to midnight)
    const startOfDayHabit = habits.find(h => h.is_start_of_day)
    const startOfDayMinutes = startOfDayHabit ? timeToMinutes(startOfDayHabit.scheduled_time) : 0
    
    // Adjust time relative to start of day (so times after start come first)
    const adjustedTime = (time: string | null): number => {
      const mins = timeToMinutes(time)
      if (mins === 9999) return 9999 // Unscheduled stays at end
      // If time is before start of day, add 24 hours to push it to "end of day"
      if (mins < startOfDayMinutes) return mins + 1440
      return mins
    }
    
    habits.sort((a, b) => {
      // Start of Day habits always first
      if (a.is_start_of_day && !b.is_start_of_day) return -1
      if (!a.is_start_of_day && b.is_start_of_day) return 1
      // Then sort by adjusted time
      return adjustedTime(a.scheduled_time) - adjustedTime(b.scheduled_time)
    })
    return habits
  }

  // Group habits by time slot (for side-by-side display of overlapping habits)
  const groupByTimeSlot = (habits: typeof habitsStore.habits) => {
    const groups: Array<{ time: string | null; habits: typeof habits }> = []
    let currentGroup: typeof habits = []
    let currentTime: string | null = null
    
    for (const habit of habits) {
      if (habit.scheduled_time !== currentTime) {
        if (currentGroup.length > 0) {
          groups.push({ time: currentTime, habits: currentGroup })
        }
        currentGroup = [habit]
        currentTime = habit.scheduled_time
      } else {
        currentGroup.push(habit)
      }
    }
    if (currentGroup.length > 0) {
      groups.push({ time: currentTime, habits: currentGroup })
    }
    return groups
  }

  const inventories = habitsStore.habitInventories.map(inv => {
    const invHabits = habitsStore.habits.filter(h => h.inventory_id === inv.id)
    sortHabits(invHabits)
    const groupedHabits = groupByTimeSlot(invHabits)
    return { ...inv, habits: invHabits, groupedHabits }
  })
  
  // Also include unassigned habits
  const unassignedHabits = habitsStore.habits.filter(h => !h.inventory_id)
  sortHabits(unassignedHabits)
  const unassignedGrouped = groupByTimeSlot(unassignedHabits)
  
  return { inventories, unassignedHabits, unassignedGrouped }
})

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

const activeFilterCount = computed(() => habitsStore.filterTags.length + (sortByTag.value ? 1 : 0))

onMounted(async () => {
  await Promise.all([
    habitsStore.fetchHabits(),
    habitsStore.fetchHabitInventories()
  ])
})

const handleCreateHabit = async () => {
  if (!newHabit.value.name.trim()) return

  // Save templates
  habitTitleTemplate.save(newHabit.value.name)
  if (newHabit.value.description) {
      habitDescriptionTemplate.save(newHabit.value.description)
  }
  
  const payload = {
    name: newHabit.value.name,
    description: newHabit.value.description || null,
    frequency: newHabit.value.frequency as 'daily' | 'weekly',
    color: newHabit.value.color,
    days_of_week: newHabit.value.frequency === 'weekly' ? newHabit.value.days_of_week : null,
    scheduled_time: newHabit.value.scheduled_time || null,
    duration_minutes: newHabit.value.duration_minutes || null,
    is_start_of_day: newHabit.value.is_start_of_day,
    inventory_id: newHabit.value.inventory_id,
    tag_ids: Array.from(newHabit.value.tag_ids)
  }
  
  await habitsStore.createHabit(payload)
  
  newHabit.value = {
    name: '',
    description: '',
    frequency: 'daily',
    color: '#10b981',
    days_of_week: [],
    scheduled_time: undefined,
    duration_minutes: undefined,
    is_start_of_day: false,
    inventory_id: undefined,
    tag_ids: new Set()
  }
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
    scheduled_time: editingHabit.value.scheduled_time || null,
    duration_minutes: editingHabit.value.duration_minutes || null,
    is_start_of_day: editingHabit.value.is_start_of_day,
    inventory_id: editingHabit.value.inventory_id,
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
  
  // Explicitly copy all properties to ensure reactivity and proper value transfer
  editingHabit.value = {
    id: habit.id,
    name: habit.name,
    description: habit.description,
    frequency: habit.frequency,
    days_of_week: habit.days_of_week || [],
    reminder_time: habit.reminder_time,
    scheduled_time: habit.scheduled_time ?? undefined,
    duration_minutes: habit.duration_minutes ?? undefined,
    color: habit.color,
    streak_count: habit.streak_count,
    longest_streak: habit.longest_streak,
    tags: habit.tags,
    completed_today: habit.completed_today,
    is_start_of_day: habit.is_start_of_day,
    inventory_id: habit.inventory_id ?? undefined,
    inserted_at: habit.inserted_at,
    updated_at: habit.updated_at,
    tag_ids: tagIds
  }
  
  showEditModal.value = true
}

const toggleDayOfWeek = (day: number, model: { days_of_week: number[] | null }) => {
  if (!model.days_of_week) {
    model.days_of_week = [day]
    return
  }
  const index = model.days_of_week.indexOf(day)
  if (index === -1) {
    model.days_of_week.push(day)
  } else {
    model.days_of_week.splice(index, 1)
  }
}

const openSkipModal = (habit: HabitWithStatus) => {
  skippingHabit.value = habit
  skipReason.value = ''
  showSkipModal.value = true
}

const handleSkipHabit = async () => {
  if (!skippingHabit.value || !skipReason.value.trim()) return
  
  await habitsStore.skipHabit(skippingHabit.value.id, skipReason.value)
  showSkipModal.value = false
  skippingHabit.value = null
  skipReason.value = ''
}

const handleCreateInventory = async () => {
  if (!newInventoryName.value.trim()) return
  
  await habitsStore.createHabitInventory({
    name: newInventoryName.value.trim(),
    color: newInventoryColor.value
  })
  newInventoryName.value = ''
  newInventoryColor.value = '#10b981'
}

const handleUpdateInventoryColor = async (inventoryId: string, color: string) => {
  await habitsStore.updateHabitInventory(inventoryId, { color })
  editingInventoryColorId.value = null
}

const toggleInventoryColorPicker = (inventoryId: string) => {
  editingInventoryColorId.value = editingInventoryColorId.value === inventoryId ? null : inventoryId
}

const completeAllInInventory = async (inventoryId: string | null) => {
  const habitIds = habitsStore.habits
    .filter(h => h.inventory_id === inventoryId && !h.completed_today)
    .map(h => h.id)
  
  if (habitIds.length > 0) {
    // Complete each habit sequentially
    for (const id of habitIds) {
      await habitsStore.completeHabit(id)
    }
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
              <span class="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Filter & Sort</span>
              <button class="text-xs text-primary hover:underline" @click="clearFilters" v-if="activeFilterCount > 0">
                Clear all
              </button>
            </div>
            
            <!-- Sort by Tag toggle -->
            <div class="px-3 py-2 border-b border-border/50">
              <label class="flex items-center gap-2 text-sm cursor-pointer">
                <input 
                  type="checkbox" 
                  v-model="sortByTag" 
                  class="h-4 w-4 rounded border-border accent-primary"
                />
                <span>Group by tag</span>
              </label>
            </div>
            
            <TagManager
              ref="filterTagManagerRef"
              v-model:checkedTagIds="filterCheckedTagIds"
              :hide-input="true"
              :compact="true"
              :embedded="true"
              :applied-tag-ids="filterAppliedTagIds"
              class="max-h-[250px] overflow-auto"
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

        <Button variant="outline" @click="showManageInventoriesModal = true">
          <Edit2 class="h-4 w-4 mr-1.5" />
          Manage Inventories
        </Button>

        <Button @click="showCreateModal = true">
          <Plus class="h-4 w-4 mr-1.5" />
          New Habit
        </Button>
      </div>
    </div>

    <!-- Tab Navigation -->
    <div class="border-b border-border">
      <div class="flex gap-1">
        <button
          :class="[
            'px-4 py-2.5 text-sm font-medium transition-colors relative',
            activeTab === 'inventory'
              ? 'text-foreground'
              : 'text-muted-foreground hover:text-foreground'
          ]"
          @click="activeTab = 'inventory'"
        >
          Inventory
          <div
            v-if="activeTab === 'inventory'"
            class="absolute bottom-0 left-0 right-0 h-0.5 bg-primary"
          />
        </button>
        <button
          :class="[
            'px-4 py-2.5 text-sm font-medium transition-colors relative',
            activeTab === 'calendar'
              ? 'text-foreground'
              : 'text-muted-foreground hover:text-foreground'
          ]"
          @click="activeTab = 'calendar'"
        >
          Calendar
          <div
            v-if="activeTab === 'calendar'"
            class="absolute bottom-0 left-0 right-0 h-0.5 bg-primary"
          />
        </button>
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

    <!-- Inventory View (Current habits list) -->
    <div v-if="activeTab === 'inventory'">
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

    <!-- Side-by-side Inventory Columns -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <!-- Inventory Columns -->
      <div 
        v-for="inv in inventoriesWithHabits.inventories" 
        :key="inv.id"
        class="flex flex-col"
      >
        <div class="flex items-center gap-2 mb-3 px-1">
          <div class="w-3 h-3 rounded-full" :style="{ backgroundColor: inv.color || '#10b981' }" />
          <h3 class="font-semibold text-sm">{{ inv.name }}</h3>
          <span class="text-xs text-muted-foreground">({{ inv.habits.length }})</span>
          <Button 
            v-if="inv.habits.some((h: any) => !h.completed_today)"
            variant="ghost" 
            size="sm" 
            class="ml-auto h-6 text-xs px-2"
            @click="completeAllInInventory(inv.id)"
          >
            <CheckCircle2 class="h-3 w-3 mr-1" />
            Complete All
          </Button>
        </div>

        <div class="flex flex-col gap-2">
          <!-- Group by time slot -->
          <div 
            v-for="(group, gIdx) in inv.groupedHabits" 
            :key="gIdx"
            :class="[
              'gap-2',
              group.habits.length > 1 ? 'grid grid-cols-2' : 'flex flex-col'
            ]"
          >
            <Card 
              v-for="habit in group.habits" 
              :key="habit.id" 
              class="group hover:shadow-md transition-all">
        <CardContent class="p-2.5">
          <div class="flex items-start gap-2">
            <!-- Complete button -->
            <button 
              @click="handleToggleComplete(habit)"
              class="shrink-0 focus:outline-none mt-0.5"
            >
              <div 
                v-if="habit.completed_today"
                class="h-7 w-7 rounded-lg flex items-center justify-center transition-all"
                :style="{ backgroundColor: habit.color + '20' }"
              >
                <CheckCircle2 class="h-4 w-4" :style="{ color: habit.color }" />
              </div>
              <div 
                v-else
                class="h-7 w-7 rounded-lg border-2 border-dashed border-muted-foreground/30 flex items-center justify-center hover:border-muted-foreground/50 transition-all"
              >
                <Circle class="h-4 w-4 text-muted-foreground/30" />
              </div>
            </button>
            
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-1.5 flex-wrap">
                <h3 
                  :class="[
                    'font-medium text-sm leading-tight',
                    habit.completed_today && 'line-through text-muted-foreground'
                  ]"
                >
                  {{ habit.name }}
                </h3>
                <Badge v-if="habit.streak_count > 0" variant="secondary" class="text-[10px] h-4 px-1">
                  <Flame class="h-2.5 w-2.5 mr-0.5" :style="{ color: habit.color }" />
                  {{ habit.streak_count }}d
                </Badge>
              </div>

              <!-- Time/Duration/Tags in compact row -->
              <div class="flex items-center gap-1 mt-1 flex-wrap">
                <Badge v-if="habit.scheduled_time" variant="secondary" class="text-[10px] h-4 px-1">
                  {{ habit.scheduled_time }}
                </Badge>
                <Badge v-if="habit.duration_minutes" variant="secondary" class="text-[10px] h-4 px-1">
                  {{ habit.duration_minutes }}m
                </Badge>
                <!-- Tags display inline -->
                <div 
                  v-for="tag in (habit.tags || []).slice(0, 2)" 
                  :key="tag.id"
                  class="h-2 w-2 rounded-full"
                  :style="{ backgroundColor: tag.color }"
                  :title="tag.name"
                />
                <span v-if="(habit.tags || []).length > 2" class="text-[9px] text-muted-foreground">+{{ habit.tags.length - 2 }}</span>
              </div>
              
              <!-- Mini heatmap for last 7 days -->
              <div class="flex items-center gap-0.5 mt-1.5">
                <div 
                  v-for="day in last7Days" 
                  :key="day.toISOString()"
                  class="w-3 h-3 rounded-sm"
                  :class="habit.completed_today && isSameDay(day, new Date()) ? '' : 'bg-secondary'"
                  :style="habit.completed_today && isSameDay(day, new Date()) ? { backgroundColor: habit.color + '40' } : {}"
                  :title="format(day, 'MMM d')"
                />
              </div>
            </div>

            <div class="flex flex-col items-center gap-0.5 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-6 w-6 text-muted-foreground"
                @click.stop="openEditModal(habit)"
              >
                <Edit2 class="h-3 w-3" />
              </Button>
              <Button 
                v-if="!habit.completed_today"
                variant="ghost" 
                size="icon" 
                class="h-6 w-6 text-orange-500 hover:text-orange-600 hover:bg-orange-500/10"
                @click.stop="openSkipModal(habit)"
                title="Skip with reason"
              >
                <Ban class="h-3 w-3" />
              </Button>
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-6 w-6 text-destructive"
                @click.stop="handleDeleteHabit(habit.id)"
              >
                <Trash2 class="h-3 w-3" />
              </Button>
            </div>
          </div>
        </CardContent>
        </Card>
          </div>
        </div>
      </div>

      <!-- Unassigned Habits Column (only if there are some) -->
      <div 
        v-if="inventoriesWithHabits.unassignedHabits.length > 0"
        class="flex flex-col"
      >
        <div class="flex items-center gap-2 mb-3 px-1">
          <div class="w-3 h-3 rounded-full bg-muted-foreground/30" />
          <h3 class="font-semibold text-sm text-muted-foreground">Unassigned</h3>
          <span class="text-xs text-muted-foreground">({{ inventoriesWithHabits.unassignedHabits.length }})</span>
          <Button 
            v-if="inventoriesWithHabits.unassignedHabits.some(h => !h.completed_today)"
            variant="ghost" 
            size="sm" 
            class="ml-auto h-6 text-xs px-2"
            @click="completeAllInInventory(null)"
          >
            <CheckCircle2 class="h-3 w-3 mr-1" />
            Complete All
          </Button>
        </div>

        <div class="flex flex-col gap-2">
          <Card 
            v-for="habit in inventoriesWithHabits.unassignedHabits" 
            :key="habit.id" 
            class="group hover:shadow-md transition-all"
          >
            <CardContent class="p-2.5">
              <div class="flex items-start gap-2">
                <button 
                  @click="handleToggleComplete(habit)"
                  class="shrink-0 focus:outline-none mt-0.5"
                >
                  <div 
                    v-if="habit.completed_today"
                    class="h-7 w-7 rounded-lg flex items-center justify-center transition-all"
                    :style="{ backgroundColor: habit.color + '20' }"
                  >
                    <CheckCircle2 class="h-4 w-4" :style="{ color: habit.color }" />
                  </div>
                  <div 
                    v-else
                    class="h-7 w-7 rounded-lg border-2 border-dashed border-muted-foreground/30 flex items-center justify-center hover:border-muted-foreground/50 transition-all"
                  >
                    <Circle class="h-4 w-4 text-muted-foreground/30" />
                  </div>
                </button>
                
                <div class="flex-1 min-w-0">
                  <h3 
                    :class="[
                      'font-medium text-sm leading-tight',
                      habit.completed_today && 'line-through text-muted-foreground'
                    ]"
                  >
                    {{ habit.name }}
                  </h3>
                  <div class="flex items-center gap-1 mt-1 flex-wrap">
                    <Badge v-if="habit.scheduled_time" variant="secondary" class="text-[10px] h-4 px-1">
                      {{ habit.scheduled_time }}
                    </Badge>
                    <Badge v-if="habit.duration_minutes" variant="secondary" class="text-[10px] h-4 px-1">
                      {{ habit.duration_minutes }}m
                    </Badge>
                  </div>
                </div>

                <div class="flex flex-col items-center gap-0.5 sm:opacity-0 sm:group-hover:opacity-100 transition-opacity">
                  <Button 
                    variant="ghost" 
                    size="icon" 
                    class="h-6 w-6 text-muted-foreground"
                    @click.stop="openEditModal(habit)"
                  >
                    <Edit2 class="h-3 w-3" />
                  </Button>
                  <Button 
                    v-if="!habit.completed_today"
                    variant="ghost" 
                    size="icon" 
                    class="h-6 w-6 text-orange-500 hover:text-orange-600 hover:bg-orange-500/10"
                    @click.stop="openSkipModal(habit)"
                    title="Skip with reason"
                  >
                    <Ban class="h-3 w-3" />
                  </Button>
                  <Button 
                    variant="ghost" 
                    size="icon" 
                    class="h-6 w-6 text-destructive"
                    @click.stop="handleDeleteHabit(habit.id)"
                  >
                    <Trash2 class="h-3 w-3" />
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
    </div>

    <!-- Calendar View -->
    <HabitCalendarView v-if="activeTab === 'calendar'" @edit="openEditModal" />

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
        <div v-if="showCreateModal" class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4" @click="showCreateModal = false">
          <div 
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden max-h-[85vh] flex flex-col"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60 shrink-0">
              <h2 class="text-lg font-semibold">Create New Habit</h2>
            </div>
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

              
              <!-- Scheduled Time and Duration -->
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Scheduled Time (optional)</label>
                  <Input 
                    v-model="newHabit.scheduled_time" 
                    type="time"
                    placeholder="09:00"
                  />
                </div>
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Duration (minutes)</label>
                  <Input 
                    v-model="newHabit.duration_minutes" 
                    type="number"
                    placeholder="30"
                    min="1"
                  />
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

              <!-- Start of Day Toggle -->
              <div class="flex items-center gap-3">
                <button
                  type="button"
                  class="h-5 w-5 rounded border-2 flex items-center justify-center transition-all"
                  :class="newHabit.is_start_of_day ? 'bg-primary border-primary' : 'border-muted-foreground/30 hover:border-muted-foreground/50'"
                  @click="newHabit.is_start_of_day = !newHabit.is_start_of_day"
                >
                  <CheckCircle2 v-if="newHabit.is_start_of_day" class="h-3 w-3 text-primary-foreground" />
                </button>
                <label class="text-sm font-medium">Start of Day</label>
                <span class="text-xs text-muted-foreground">(Always appears first)</span>
              </div>

              <!-- Inventory Selection -->
              <div v-if="habitsStore.habitInventories.length > 0">
                <label class="text-sm font-medium mb-1.5 block">Inventory</label>
                <Select
                  v-model="newHabit.inventory_id"
                  :options="[
                    { value: undefined, label: 'No inventory (default)' },
                    ...habitsStore.habitInventories.map(inv => ({ value: inv.id, label: inv.name }))
                  ]"
                  placeholder="Select inventory"
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

              <!-- Scheduled Time -->
              <div>
                <label class="text-sm font-medium mb-1.5 block">Scheduled Time (optional)</label>
                <Input
                  type="time"
                  :model-value="editingHabit.scheduled_time ?? ''"
                  @update:model-value="editingHabit!.scheduled_time = $event || undefined"
                  placeholder="HH:MM"
                />
              </div>

              <!-- Duration -->
              <div>
                <label class="text-sm font-medium mb-1.5 block">Duration (minutes)</label>
                <Input
                  type="number"
                  :model-value="editingHabit.duration_minutes ?? ''"
                  @update:model-value="editingHabit!.duration_minutes = $event ? Number($event) : undefined"
                  placeholder="30"
                  min="1"
                />
              </div>

              <!-- Frequency -->
              <div>
                <label class="text-sm font-medium mb-1.5 block">Frequency</label>
                <Select 
                  v-model="editingHabit.frequency"
                  :options="[
                    { value: 'daily', label: 'Daily' },
                    { value: 'weekly', label: 'Weekly (specific days)' }
                  ]"
                  placeholder="Select frequency"
                />
              </div>

              <!-- Start of Day Toggle -->
              <div class="flex items-center gap-3">
                <button
                  type="button"
                  class="h-5 w-5 rounded border-2 flex items-center justify-center transition-all"
                  :class="editingHabit.is_start_of_day ? 'bg-primary border-primary' : 'border-muted-foreground/30 hover:border-muted-foreground/50'"
                  @click="editingHabit.is_start_of_day = !editingHabit.is_start_of_day"
                >
                  <CheckCircle2 v-if="editingHabit.is_start_of_day" class="h-3 w-3 text-primary-foreground" />
                </button>
                <label class="text-sm font-medium">Start of Day</label>
                <span class="text-xs text-muted-foreground">(Always appears first)</span>
              </div>

              <!-- Inventory Selection -->
              <div v-if="habitsStore.habitInventories.length > 0">
                <label class="text-sm font-medium mb-1.5 block">Inventory</label>
                <Select
                  v-model="editingHabit!.inventory_id"
                  :options="[
                    { value: undefined, label: 'No inventory (default)' },
                    ...habitsStore.habitInventories.map(inv => ({ value: inv.id, label: inv.name }))
                  ]"
                  placeholder="Select inventory"
                />
              </div>

              <!-- Days of Week (only for weekly habits) -->
              <div v-if="editingHabit.frequency === 'weekly'">
                <label class="text-sm font-medium mb-1.5 block">Days of Week</label>
                <div class="flex gap-2">
                  <button
                    v-for="(day, index) in weekDays"
                    :key="index"
                    type="button"
                    class="px-3 py-2 rounded-lg text-sm font-medium transition-colors"
                    :class="(editingHabit.days_of_week || []).includes(index) ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'"
                    @click="toggleDayOfWeek(index, editingHabit!)"
                  >
                    {{ day }}
                  </button>
                </div>
              </div>

              <!-- Tags -->
              <CollapsibleTagManager
                :applied-tag-ids="editingHabit!.tag_ids"
                :tags="resolveTags(editingHabit!.tag_ids)"
                :reset-trigger="!showEditModal"
                @add-tags="(tags) => handleAddTags(editingHabit!.tag_ids, tags)"
                @remove-tag="(id) => handleRemoveTag(editingHabit!.tag_ids, id)"
              />

              <div>
                <label class="text-sm font-medium mb-1.5 block">Color</label>
                <div class="flex gap-2">
                  <button
                    v-for="color in colors"
                    :key="color"
                    class="w-8 h-8 rounded-lg transition-all"
                    :class="editingHabit!.color === color ? 'ring-2 ring-offset-2 ring-offset-background' : 'hover:scale-110'"
                    :style="{ backgroundColor: color, '--tw-ring-color': color } as any"
                    @click="editingHabit!.color = color"
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

    <!-- Skip Habit Modal -->
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
          v-if="showManageInventoriesModal"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          @click="showManageInventoriesModal = false"
        >
          <div 
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60 flex items-center justify-between">
              <h2 class="text-lg font-semibold">Manage Inventories</h2>
              <button @click="showManageInventoriesModal = false" class="p-1 hover:bg-muted rounded-lg transition-colors">
                <X class="h-4 w-4" />
              </button>
            </div>
            <div class="p-5 space-y-4 max-h-[60vh] overflow-y-auto">
              <div v-if="habitsStore.habitInventories.length > 0" class="space-y-2">
                <div 
                  v-for="inv in habitsStore.habitInventories" 
                  :key="inv.id"
                  class="flex items-center justify-between p-3 bg-muted/30 rounded-lg gap-2"
                >
                  <div class="flex items-center gap-2 flex-1">
                    <!-- Color picker dropdown -->
                    <div class="relative">
                      <button 
                        @click="toggleInventoryColorPicker(inv.id)"
                        class="w-5 h-5 rounded-full border-2 border-border hover:border-primary transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2"
                        :style="{ backgroundColor: inv.color || '#10b981' }"
                        title="Change color"
                      />
                      <!-- Color picker popup -->
                      <div 
                        v-if="editingInventoryColorId === inv.id"
                        class="absolute left-0 top-full mt-1 p-2 bg-card border border-border rounded-lg shadow-xl z-10 flex gap-1"
                      >
                        <button
                          v-for="color in colors"
                          :key="color"
                          class="w-6 h-6 rounded-full transition-all focus:outline-none"
                          :class="inv.color === color ? 'ring-2 ring-offset-1 ring-offset-background' : 'hover:scale-110'"
                          :style="{ backgroundColor: color, '--tw-ring-color': color } as any"
                          @click="handleUpdateInventoryColor(inv.id, color)"
                        />
                      </div>
                    </div>
                    <span class="font-medium">{{ inv.name }}</span>
                  </div>
                  <button 
                    @click="habitsStore.deleteHabitInventory(inv.id)"
                    class="p-1.5 text-muted-foreground hover:text-destructive hover:bg-destructive/10 rounded transition-colors"
                  >
                    <Trash2 class="h-4 w-4" />
                  </button>
                </div>
              </div>

              <div v-else class="text-center py-4 text-muted-foreground text-sm">
                No inventories yet. Create one to group your habits.
              </div>
              <div class="border-t border-border/60 pt-4 space-y-3">
                <!-- Color selection for new inventory -->
                <div class="flex items-center gap-2">
                  <span class="text-sm text-muted-foreground">Color:</span>
                  <div class="flex gap-1">
                    <button
                      v-for="color in colors"
                      :key="color"
                      class="w-5 h-5 rounded-full transition-all focus:outline-none"
                      :class="newInventoryColor === color ? 'ring-2 ring-offset-1 ring-offset-background' : 'hover:scale-110'"
                      :style="{ backgroundColor: color, '--tw-ring-color': color } as any"
                      @click="newInventoryColor = color"
                    />
                  </div>
                </div>
                <div class="flex gap-2">
                  <Input 
                    v-model="newInventoryName"
                    placeholder="New inventory name..."
                    class="flex-1"
                    @keydown.enter="handleCreateInventory"
                  />
                  <Button @click="handleCreateInventory" :disabled="!newInventoryName.trim()">
                    <Plus class="h-4 w-4" />
                  </Button>
                </div>
              </div>

            </div>
          </div>
        </div>
      </Transition>

      <!-- Skip Habit Modal -->
      <Transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div 
          v-if="showSkipModal && skippingHabit"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          @click="showSkipModal = false"
        >
          <div 
            class="w-full max-w-md bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Skip: {{ skippingHabit.name }}</h2>
              <p class="text-sm text-muted-foreground mt-1">Why are you skipping this habit today?</p>
            </div>
            <div class="p-5 space-y-4">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Reason</label>
                <textarea 
                  v-model="skipReason"
                  placeholder="e.g., Not feeling well, Too busy, etc."
                  class="w-full px-3 py-2 bg-background border border-border rounded-lg focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent resize-none text-sm"
                  rows="3"
                  @keydown.enter.meta.prevent="handleSkipHabit"
                  @keydown.enter.ctrl.prevent="handleSkipHabit"
                />
                <p class="text-xs text-muted-foreground mt-1.5">This helps you understand your patterns and improve consistency.</p>
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-between gap-2">
              <Button variant="ghost" @click="showSkipModal = false">Cancel</Button>
              <Button @click="handleSkipHabit" :disabled="!skipReason.trim()">
                <Ban class="h-4 w-4 mr-1.5" />
                Skip Today
              </Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

