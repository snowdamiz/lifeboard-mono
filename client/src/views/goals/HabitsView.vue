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
  scheduled_time: string | null
  duration_minutes: number | null
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
  days_of_week: [0, 1, 2, 3, 4, 5, 6] as number[],
  scheduled_time: null as string | null,
  duration_minutes: null as number | null,
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

// Timeline zoom scale (pixels per minute) - user adjustable
const timelineScale = ref(3)
const MIN_SCALE = 1
const MAX_SCALE = 10
const MIN_CARD_HEIGHT = 16

// Calculate auto-scale to prevent overlaps for a set of habits
const calculateAutoScale = (habits: HabitWithStatus[]): number => {
  if (habits.length === 0) return 3
  
  // Filter habits with scheduled times
  const scheduledHabits = habits.filter(h => h.scheduled_time)
  if (scheduledHabits.length === 0) return 3
  
  // Find maximum overlap at any point in time
  // For each habit, find how many other habits overlap with it
  let maxOverlapDuration = 0
  let maxOverlapCount = 1
  
  for (let i = 0; i < scheduledHabits.length; i++) {
    const habit = scheduledHabits[i]
    const start = timeToMinutes(habit.scheduled_time)
    const end = start + (habit.duration_minutes || 30)
    
    // Find all habits that overlap with this one
    let overlapCount = 1
    for (let j = 0; j < scheduledHabits.length; j++) {
      if (i === j) continue
      const otherStart = timeToMinutes(scheduledHabits[j].scheduled_time)
      const otherEnd = otherStart + (scheduledHabits[j].duration_minutes || 30)
      
      // Check if they overlap
      if (otherStart < end && otherEnd > start) {
        overlapCount++
      }
    }
    
    if (overlapCount > maxOverlapCount) {
      maxOverlapCount = overlapCount
      // Find the minimum overlap duration (where they all overlap)
      const overlappers = [habit, ...scheduledHabits.filter((h, idx) => {
        if (idx === i) return false
        const os = timeToMinutes(h.scheduled_time)
        const oe = os + (h.duration_minutes || 30)
        return os < end && oe > start
      })]
      
      // Calculate the shared overlap window
      const overlapStart = Math.max(...overlappers.map(h => timeToMinutes(h.scheduled_time)))
      const overlapEnd = Math.min(...overlappers.map(h => timeToMinutes(h.scheduled_time) + (h.duration_minutes || 30)))
      maxOverlapDuration = Math.max(maxOverlapDuration, overlapEnd - overlapStart)
    }
  }
  
  if (maxOverlapCount <= 1 || maxOverlapDuration <= 0) return 3
  
  // Calculate minimum scale: need (overlapCount * minCardHeight) pixels for overlapDuration minutes
  const requiredScale = (maxOverlapCount * MIN_CARD_HEIGHT) / maxOverlapDuration
  
  // Clamp to reasonable range
  return Math.max(MIN_SCALE, Math.min(MAX_SCALE, Math.ceil(requiredScale)))
}

// Helper to parse time string (HH:MM) to minutes since midnight
const timeToMinutes = (timeStr: string | null): number => {
  if (!timeStr) return 9999 // Put unscheduled habits at the end
  const [hours, minutes] = timeStr.split(':').map(Number)
  return hours * 60 + minutes
}

// Format duration in minutes as "Xh Ym" when >= 60, or "Xm" when < 60
const formatDuration = (minutes: number | null): string => {
  if (!minutes || minutes <= 0) return ''
  if (minutes < 60) return `${minutes}m`
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  if (mins === 0) return `${hours}h`
  return `${hours}h ${mins}m`
}

// Parse duration from HH:MM format to total minutes
const parseDuration = (timeStr: string): number | null => {
  if (!timeStr) return null
  const parts = timeStr.split(':').map(Number)
  if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
    return parts[0] * 60 + parts[1]
  }
  // If just a number, treat as minutes
  const asNum = Number(timeStr)
  if (!isNaN(asNum)) return asNum
  return null
}

// Format minutes as HH:MM for input field
const formatTimeForInput = (minutes: number | null | undefined): string => {
  if (!minutes || minutes <= 0) return ''
  const hours = Math.floor(minutes / 60)
  const mins = minutes % 60
  return `${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`
}

// Calculate total time span for a list of habits (earliest start to latest end)
// This handles overlapping habits correctly by using the actual time span
const calculateTotalDuration = (habits: HabitWithStatus[]): number => {
  if (habits.length === 0) return 0
  
  let startTime = Infinity
  let endTime = 0
  
  for (const habit of habits) {
    if (!habit.scheduled_time) continue
    const habitStart = timeToMinutes(habit.scheduled_time)
    const habitEnd = habitStart + (habit.duration_minutes || 0)
    
    // Track earliest start
    if (habitStart < startTime) startTime = habitStart
    
    // Track latest end (considering duration)
    if (habitEnd > endTime) endTime = habitEnd
  }
  
  // If no scheduled habits, fall back to sum of durations
  if (startTime === Infinity) {
    return habits.reduce((sum, h) => sum + (h.duration_minutes || 0), 0)
  }
  
  return endTime - startTime
}

// Calculate time available for an inventory based on its habits
const calculateTimeAvailable = (inv: { 
  coverage_mode?: 'whole_day' | 'partial_day', 
  day_start_time?: string | null, 
  day_end_time?: string | null 
}, habits: HabitWithStatus[]): number => {
  if (inv.coverage_mode === 'whole_day') {
    return 1440 // 24 hours
  }
  
  // For partial day, calculate from habits or explicit start/end
  if (inv.day_start_time && inv.day_end_time) {
    const start = timeToMinutes(inv.day_start_time)
    const end = timeToMinutes(inv.day_end_time)
    return end > start ? end - start : (1440 - start + end)
  }
  
  // Calculate from habits
  if (habits.length === 0) return 0
  
  let startTime = 9999
  let endTime = 0
  
  for (const habit of habits) {
    if (!habit.scheduled_time) continue
    const habitStart = timeToMinutes(habit.scheduled_time)
    const habitEnd = habitStart + (habit.duration_minutes || 0)
    
    // Track earliest start
    if (habitStart < startTime) startTime = habitStart
    
    // Track latest end (considering duration)
    if (habitEnd > endTime) endTime = habitEnd
  }
  
  // Handle unscheduled or invalid case
  if (startTime === 9999) return 0
  
  return endTime - startTime
}

// Format time in HH:MM as readable (e.g., "9:00am")
const formatTimeReadable = (timeStr: string | null): string => {
  if (!timeStr) return ''
  const [hours, minutes] = timeStr.split(':').map(Number)
  const period = hours >= 12 ? 'pm' : 'am'
  const displayHour = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours
  return `${displayHour}:${minutes.toString().padStart(2, '0')}${period}`
}

// Convert minutes to time string HH:MM
const minutesToTimeStr = (mins: number): string => {
  const hours = Math.floor(mins / 60) % 24
  const minutes = mins % 60
  return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`
}

// Calculate timeline range for a set of habits
const getTimelineRange = (habits: HabitWithStatus[]): { startMins: number, endMins: number, hourMarks: number[] } => {
  let startMins = 24 * 60 // Default to end of day
  let endMins = 0

  for (const habit of habits) {
    if (!habit.scheduled_time) continue
    const habitStart = timeToMinutes(habit.scheduled_time)
    const habitEnd = habitStart + (habit.duration_minutes || 30)
    
    if (habitStart < startMins) startMins = habitStart
    if (habitEnd > endMins) endMins = habitEnd
  }

  // Default to 6am-10pm if no habits
  if (startMins >= endMins) {
    startMins = 6 * 60  // 6am
    endMins = 22 * 60   // 10pm
  }

  // Round to nearest hour for cleaner display
  startMins = Math.floor(startMins / 60) * 60
  endMins = Math.ceil(endMins / 60) * 60

  // Generate hour marks for the timeline
  const hourMarks: number[] = []
  for (let m = startMins; m <= endMins; m += 60) {
    hourMarks.push(m)
  }

  return { startMins, endMins, hourMarks }
}

// Calculate vertical position for a habit on the timeline
// Top is percentage-based for positioning, height is pixel-based for consistent sizing
const getHabitPosition = (habit: HabitWithStatus, startMins: number, endMins: number): { top: number, heightPx: number } => {
  if (!habit.scheduled_time) return { top: 0, heightPx: MIN_CARD_HEIGHT }
  
  const habitStart = timeToMinutes(habit.scheduled_time)
  const duration = habit.duration_minutes || 30
  const range = endMins - startMins
  
  const top = ((habitStart - startMins) / range) * 100
  // Height in pixels based on duration and current timeline scale
  const heightPx = Math.max(duration * timelineScale.value, MIN_CARD_HEIGHT)
  
  return { top, heightPx }
}

// Assign columns to habits - single column layout (no horizontal overlap)
// Returns habits with column assignment and total column count
type HabitWithColumn = HabitWithStatus & { column: number }
const assignColumnsToHabits = (habits: HabitWithStatus[]): { habits: HabitWithColumn[], columnCount: number } => {
  if (habits.length === 0) return { habits: [], columnCount: 1 }
  
  // Sort by start time
  const sorted = [...habits].sort((a, b) => {
    const aStart = a.scheduled_time ? timeToMinutes(a.scheduled_time) : 0
    const bStart = b.scheduled_time ? timeToMinutes(b.scheduled_time) : 0
    return aStart - bStart
  })
  
  // All habits in single column - no horizontal splitting
  const result: HabitWithColumn[] = sorted.map(habit => ({ ...habit, column: 0 }))
  
  return { habits: result, columnCount: 1 }
}

// Group whole-day inventories with their linked partial-day sheets
const timelineInventoryGroups = computed(() => {
  const allInvs = inventoriesWithHabits.value.inventories
  const wholeDayInvs = allInvs.filter(inv => inv.coverage_mode === 'whole_day')
  const usedPartialIds = new Set<string>()

  const groups = wholeDayInvs.map(wholeDay => {
    const linkedPartials = (wholeDay.linked_inventory_ids || [])
      .map(id => allInvs.find(inv => inv.id === id))
      .filter((p): p is NonNullable<typeof p> => p !== undefined)
      .map(p => {
        // Add column assignments and time range for each partial
        const { habits: columnHabits, columnCount } = assignColumnsToHabits(p.habits)
        const timeRange = getTimelineRange(p.habits)
        return { ...p, columnHabits, columnCount, timeRange }
      })
    
    linkedPartials.forEach(p => usedPartialIds.add(p.id))

    // Combine all habits for timeline range calculation
    const allHabits = [...wholeDay.habits, ...linkedPartials.flatMap(p => p.habits)]
    const timeRange = getTimelineRange(allHabits)

    // Re-compute column assignments for whole-day inventory
    const { habits: wholeDayColumnHabits, columnCount: wholeDayColumnCount } = assignColumnsToHabits(wholeDay.habits)

    return {
      wholeDay: {
        ...wholeDay,
        columnHabits: wholeDayColumnHabits,
        columnCount: wholeDayColumnCount
      },
      linkedPartials,
      timeRange
    }
  })

  // Standalone inventories (partial day without links, or not linked to any whole day)
  const standaloneInvs = allInvs.filter(inv => 
    inv.coverage_mode !== 'whole_day' && !usedPartialIds.has(inv.id)
  )

  return { groups, standaloneInvs }
})

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
    const totalPlanned = calculateTotalDuration(invHabits)
    const timeAvailable = calculateTimeAvailable(inv, invHabits)
    // Calculate max overlap count (max habits sharing same time slot)
    const maxOverlapCount = groupedHabits.reduce((max, g) => Math.max(max, g.habits.length), 1)
    // Calculate column assignments for timeline view
    const { habits: columnHabits, columnCount } = assignColumnsToHabits(invHabits)
    // Calculate timeline range
    const timeRange = getTimelineRange(invHabits)
    return { ...inv, habits: invHabits, groupedHabits, totalPlanned, timeAvailable, maxOverlapCount, columnHabits, columnCount, timeRange }
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
    days_of_week: [0, 1, 2, 3, 4, 5, 6], 
    scheduled_time: null, 
    duration_minutes: null, 
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

const handleDeleteInventory = async (id: string) => {
  if (confirm('Are you sure you want to delete this habit sheet and all its habits?')) {
    await habitsStore.deleteHabitInventory(id)
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
    scheduled_time: habit.scheduled_time ?? null,
    duration_minutes: habit.duration_minutes ?? null,
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

// Repetition presets for quick day selection
type RepetitionMode = 'daily' | 'weekdays' | 'weekends' | 'custom'

const getRepetitionMode = (days: number[]): RepetitionMode => {
  const sorted = [...days].sort((a, b) => a - b)
  if (sorted.length === 7 && sorted.every((d, i) => d === i)) return 'daily'
  if (sorted.length === 5 && sorted.every((d, i) => d === i + 1)) return 'weekdays'
  if (sorted.length === 2 && sorted[0] === 0 && sorted[1] === 6) return 'weekends'
  return 'custom'
}

const setRepetitionMode = (
  mode: RepetitionMode,
  model: { frequency: string; days_of_week: number[] }
) => {
  switch (mode) {
    case 'daily':
      model.frequency = 'daily'
      model.days_of_week = [0, 1, 2, 3, 4, 5, 6]
      break
    case 'weekdays':
      model.frequency = 'weekly'
      model.days_of_week = [1, 2, 3, 4, 5]
      break
    case 'weekends':
      model.frequency = 'weekly'
      model.days_of_week = [0, 6]
      break
    case 'custom':
      model.frequency = 'weekly'
      // Keep existing days if already custom, else clear
      if (getRepetitionMode(model.days_of_week) !== 'custom') {
        model.days_of_week = []
      }
      break
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

const handleUpdateCoverageMode = async (inventoryId: string, mode: 'whole_day' | 'partial_day') => {
  console.log('Updating coverage mode:', inventoryId, mode)
  try {
    await habitsStore.updateHabitInventory(inventoryId, { coverage_mode: mode })
    console.log('Coverage mode updated successfully')
  } catch (error) {
    console.error('Failed to update coverage mode:', error)
  }
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

    <!-- Timeline Zoom Controls -->
    <div v-if="activeTab === 'inventory' && habitsStore.habits.length > 0" class="flex items-center gap-3 bg-card/50 rounded-lg px-3 py-2 border border-border/50">
      <span class="text-xs text-muted-foreground">Zoom:</span>
      <Button 
        variant="ghost" 
        size="icon" 
        class="h-6 w-6"
        :disabled="timelineScale <= MIN_SCALE"
        @click="timelineScale = Math.max(MIN_SCALE, timelineScale - 1)"
      >
        <MinusCircle class="h-4 w-4" />
      </Button>
      <span class="text-sm font-medium w-8 text-center">{{ timelineScale }}x</span>
      <Button 
        variant="ghost" 
        size="icon" 
        class="h-6 w-6"
        :disabled="timelineScale >= MAX_SCALE"
        @click="timelineScale = Math.min(MAX_SCALE, timelineScale + 1)"
      >
        <PlusCircle class="h-4 w-4" />
      </Button>
      <div class="w-px h-4 bg-border mx-1" />
      <Button 
        variant="outline" 
        size="sm" 
        class="h-6 text-xs"
        @click="timelineScale = calculateAutoScale(habitsStore.habits)"
      >
        Auto-Size
      </Button>
    </div>

    <!-- All Inventories - Flow-based single-column layout -->
    <div v-if="habitsStore.habits.length > 0" class="flex flex-col gap-6">
      <!-- Whole-Day Groups with Linked Inventories (Side-by-Side Layout) -->
      <div 
        v-for="(group, gIdx) in timelineInventoryGroups.groups" 
        :key="'timeline-' + gIdx"
        class="flex flex-col gap-2"
      >
        <!-- Full-width header for the whole group -->
        <div class="flex items-center gap-2 group/header">
          <div class="w-3 h-3 rounded-full" :style="{ backgroundColor: group.wholeDay.color || '#10b981' }" />
          <h3 class="font-semibold">{{ group.wholeDay.name }}</h3>
          <Badge variant="secondary" class="text-xs">Whole Day</Badge>
          <span class="text-xs text-muted-foreground">({{ group.wholeDay.habits.length }})</span>
          <span class="text-xs text-muted-foreground">{{ formatDuration(group.wholeDay.totalPlanned) }} / {{ formatDuration(group.wholeDay.timeAvailable) }}</span>
          <Button 
            variant="ghost" 
            size="icon" 
            class="h-6 w-6 opacity-0 group-hover/header:opacity-100 transition-opacity text-destructive hover:text-destructive hover:bg-destructive/10"
            @click.stop="handleDeleteInventory(group.wholeDay.id)"
            title="Delete habit sheet"
          >
            <Trash2 class="h-3.5 w-3.5" />
          </Button>
          <Button 
            v-if="group.wholeDay.habits.some((h: any) => !h.completed_today)"
            variant="ghost" 
            size="sm" 
            class="ml-auto h-6 text-xs px-2"
            @click="completeAllInInventory(group.wholeDay.id)"
          >
            <CheckCircle2 class="h-3 w-3 mr-1" />
            Complete All
          </Button>
        </div>

        <!-- Side-by-Side Container: Whole Day (left) + Partial Days (right) -->
        <div class="flex gap-4">
          <!-- Left: Whole Day Sheet (50% width, or full width if no linked partials) -->
          <div :class="group.linkedPartials.length > 0 ? 'w-1/2' : 'w-full'">
            <!-- Whole Day Habits - Timeline with time markers and duration-based heights -->
            <div class="flex gap-2 overflow-hidden">
              <!-- Time markers column -->
              <div class="w-12 shrink-0 relative overflow-hidden" :style="{ minHeight: `${Math.max(200, (group.timeRange.endMins - group.timeRange.startMins) * timelineScale)}px` }">
                <div 
                  v-for="hour in group.timeRange.hourMarks" 
                  :key="hour"
                  class="absolute left-0 right-0 text-[10px] text-muted-foreground border-t border-border/30"
                  :style="{ top: `${((hour - group.timeRange.startMins) / (group.timeRange.endMins - group.timeRange.startMins)) * 100}%` }"
                >
                  {{ minutesToTimeStr(hour).slice(0, 5) }}
                </div>
              </div>
              
              <!-- Habits container with absolute positioning -->
              <div 
                class="flex-1 relative overflow-hidden"
                :style="{ minHeight: `${Math.max(200, (group.timeRange.endMins - group.timeRange.startMins) * timelineScale)}px` }"
              >
                <Card 
                  v-for="habit in group.wholeDay.columnHabits" 
                  :key="habit.id"
                  class="absolute group hover:shadow-md transition-all cursor-pointer overflow-hidden"
                  :style="{ 
                    top: `${getHabitPosition(habit, group.timeRange.startMins, group.timeRange.endMins).top}%`,
                    height: `${getHabitPosition(habit, group.timeRange.startMins, group.timeRange.endMins).heightPx}px`,
                    left: `${(habit.column / group.wholeDay.columnCount) * 100}%`,
                    width: `${(1 / group.wholeDay.columnCount) * 100 - 1}%`,
                    borderLeft: `3px solid ${habit.color || group.wholeDay.color || '#10b981'}`
                  }"
                  @click="openEditModal(habit)"
                >
                  <CardContent class="p-1.5 h-full">
                    <div class="flex items-start gap-1.5 h-full">
                      <button @click.stop="handleToggleComplete(habit)" class="shrink-0 mt-0.5">
                        <div 
                          v-if="habit.completed_today"
                          class="h-4 w-4 rounded flex items-center justify-center"
                          :style="{ backgroundColor: habit.color + '20' }"
                        >
                          <CheckCircle2 class="h-2.5 w-2.5" :style="{ color: habit.color }" />
                        </div>
                        <div v-else class="h-4 w-4 rounded border-2 border-dashed border-muted-foreground/30 flex items-center justify-center hover:border-muted-foreground/50">
                          <Circle class="h-2.5 w-2.5 text-muted-foreground/30" />
                        </div>
                      </button>
                      <div class="flex-1 min-w-0 overflow-hidden">
                        <h4 :class="['text-xs font-medium truncate', habit.completed_today && 'line-through text-muted-foreground']" :title="habit.name">{{ habit.name }}</h4>
                        <div class="flex items-center gap-1">
                          <span class="text-[9px] text-muted-foreground">{{ formatTimeReadable(habit.scheduled_time) }}</span>
                          <span v-if="habit.duration_minutes" class="text-[9px] text-muted-foreground">· {{ formatDuration(habit.duration_minutes) }}</span>
                        </div>
                      </div>
                      <div class="flex flex-col gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                        <Button 
                          v-if="!habit.completed_today"
                          variant="ghost" 
                          size="icon" 
                          class="h-4 w-4 text-orange-500 hover:text-orange-600 hover:bg-orange-500/10"
                          @click.stop="openSkipModal(habit)"
                          title="Skip with reason"
                        >
                          <Ban class="h-2 w-2" />
                        </Button>
                        <Button 
                          variant="ghost" 
                          size="icon" 
                          class="h-4 w-4 text-destructive"
                          @click.stop="handleDeleteHabit(habit.id)"
                        >
                          <Trash2 class="h-2 w-2" />
                        </Button>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            </div>
          </div>

          <!-- Right: Linked Partial-Day Inventories (50% width, stacked vertically) -->
          <div v-if="group.linkedPartials.length > 0" class="w-1/2 flex flex-col gap-3 pl-3 border-l-2 border-dashed border-border/50">
            <div 
              v-for="partial in group.linkedPartials" 
              :key="partial.id"
            >
          <!-- Partial Inventory Header -->
          <div class="flex items-center gap-2 mb-2 group/partialheader">
            <div class="w-2.5 h-2.5 rounded-full" :style="{ backgroundColor: partial.color || '#10b981' }" />
            <span class="text-sm font-medium">{{ partial.name }}</span>
            <span class="text-xs text-muted-foreground">({{ partial.habits.length }})</span>
            <span class="text-xs text-muted-foreground">{{ formatDuration(partial.totalPlanned) }} / {{ formatDuration(partial.timeAvailable) }}</span>
            <Button 
              variant="ghost" 
              size="icon" 
              class="h-5 w-5 opacity-0 group-hover/partialheader:opacity-100 transition-opacity text-destructive hover:text-destructive hover:bg-destructive/10"
              @click.stop="handleDeleteInventory(partial.id)"
              title="Delete habit sheet"
            >
              <Trash2 class="h-2.5 w-2.5" />
            </Button>
            <Button 
              v-if="partial.habits.some((h: any) => !h.completed_today)"
              variant="ghost" 
              size="sm" 
              class="ml-auto h-5 text-[10px] px-1.5"
              @click="completeAllInInventory(partial.id)"
            >
              <CheckCircle2 class="h-2.5 w-2.5 mr-0.5" />
              All
            </Button>
          </div>

          <!-- Partial Habits - Aligned with whole day timeline (no separate time markers) -->
          <div class="relative" v-if="partial.columnHabits && partial.columnHabits.length > 0"
            :style="{ minHeight: `${Math.max(200, (group.timeRange.endMins - group.timeRange.startMins) * timelineScale)}px` }"
          >
              <Card 
                v-for="habit in partial.columnHabits" 
                :key="habit.id"
                class="absolute group hover:shadow-sm transition-all cursor-pointer overflow-hidden"
                :style="{ 
                  top: `${getHabitPosition(habit, group.timeRange.startMins, group.timeRange.endMins).top}%`,
                  height: `${getHabitPosition(habit, group.timeRange.startMins, group.timeRange.endMins).heightPx}px`,
                  left: `${(habit.column / partial.columnCount) * 100}%`,
                  width: `${(1 / partial.columnCount) * 100 - 1}%`,
                  borderLeft: `2px solid ${habit.color || partial.color || '#10b981'}`
                }"
                @click="openEditModal(habit)"
              >
                <CardContent class="p-1 h-full">
                  <div class="flex items-start gap-1 h-full">
                    <button @click.stop="handleToggleComplete(habit)" class="shrink-0">
                      <div 
                        v-if="habit.completed_today"
                        class="h-3.5 w-3.5 rounded flex items-center justify-center"
                        :style="{ backgroundColor: habit.color + '20' }"
                      >
                        <CheckCircle2 class="h-2 w-2" :style="{ color: habit.color }" />
                      </div>
                      <div v-else class="h-3.5 w-3.5 rounded border-2 border-dashed border-muted-foreground/30 flex items-center justify-center">
                        <Circle class="h-2 w-2 text-muted-foreground/30" />
                      </div>
                    </button>
                    <div class="flex-1 min-w-0 overflow-hidden">
                      <h5 :class="['text-[10px] font-medium truncate', habit.completed_today && 'line-through text-muted-foreground']" :title="habit.name">{{ habit.name }}</h5>
                      <span class="text-[8px] text-muted-foreground">{{ formatTimeReadable(habit.scheduled_time) }}</span>
                    </div>
                  </div>
                </CardContent>
              </Card>
          </div>
        </div>
          </div>
        </div>
      </div>

      <!-- Standalone Inventories (full width, habits flow in multiple columns) -->
      <div v-if="timelineInventoryGroups.standaloneInvs.length > 0" class="flex flex-col gap-6">

      <!-- Each Inventory as a Full-Width Section -->
      <div 
        v-for="inv in timelineInventoryGroups.standaloneInvs" 
        :key="inv.id"
        class="flex flex-col"
      >
        <div class="flex items-center gap-2 mb-3 px-1 flex-wrap group/standaloneheader">
          <div class="w-3 h-3 rounded-full shrink-0" :style="{ backgroundColor: inv.color || '#10b981' }" />
          <h3 class="font-semibold text-sm">{{ inv.name }}</h3>
          <span class="text-xs text-muted-foreground">({{ inv.habits.length }})</span>
          <Button 
            variant="ghost" 
            size="icon" 
            class="h-5 w-5 opacity-0 group-hover/standaloneheader:opacity-100 transition-opacity text-destructive hover:text-destructive hover:bg-destructive/10"
            @click.stop="handleDeleteInventory(inv.id)"
            title="Delete habit sheet"
          >
            <Trash2 class="h-3 w-3" />
          </Button>
          <!-- Time metrics -->
          <Badge v-if="inv.totalPlanned > 0" variant="secondary" class="text-[10px] h-4 px-1.5">
            {{ formatDuration(inv.totalPlanned) }}
            <template v-if="inv.timeAvailable > 0">
              / {{ formatDuration(inv.timeAvailable) }}
            </template>
          </Badge>
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

        <!-- Timeline layout with columns -->
        <div class="flex gap-2" v-if="inv.columnHabits && inv.columnHabits.length > 0">
          <!-- Time markers column -->
          <div class="w-12 shrink-0 relative" :style="{ minHeight: `${Math.max(150, (inv.timeRange.endMins - inv.timeRange.startMins) / 2.5)}px` }">
            <div 
              v-for="hour in inv.timeRange.hourMarks" 
              :key="hour"
              class="absolute left-0 right-0 text-[9px] text-muted-foreground border-t border-border/30"
              :style="{ top: `${((hour - inv.timeRange.startMins) / (inv.timeRange.endMins - inv.timeRange.startMins)) * 100}%` }"
            >
              {{ minutesToTimeStr(hour).slice(0, 5) }}
            </div>
          </div>
          
          <!-- Habits container with absolute positioning -->
          <div 
            class="flex-1 relative"
            :style="{ minHeight: `${Math.max(150, (inv.timeRange.endMins - inv.timeRange.startMins) / 2.5)}px` }"
          >
            <Card 
              v-for="habit in inv.columnHabits" 
              :key="habit.id"
              class="absolute group hover:shadow-md transition-all cursor-pointer overflow-hidden"
              :style="{ 
                top: `${getHabitPosition(habit, inv.timeRange.startMins, inv.timeRange.endMins).top}%`,
                height: `${getHabitPosition(habit, inv.timeRange.startMins, inv.timeRange.endMins).heightPx}px`,
                left: `${(habit.column / inv.columnCount) * 100}%`,
                width: `${(1 / inv.columnCount) * 100 - 1}%`,
                borderLeft: `3px solid ${habit.color || inv.color || '#10b981'}`
              }"
              @click="openEditModal(habit)"
            >
              <CardContent class="p-1.5 h-full">
                <div class="flex items-start gap-1.5 h-full">
                  <button @click.stop="handleToggleComplete(habit)" class="shrink-0 mt-0.5">
                    <div 
                      v-if="habit.completed_today"
                      class="h-4 w-4 rounded flex items-center justify-center"
                      :style="{ backgroundColor: habit.color + '20' }"
                    >
                      <CheckCircle2 class="h-2.5 w-2.5" :style="{ color: habit.color }" />
                    </div>
                    <div v-else class="h-4 w-4 rounded border-2 border-dashed border-muted-foreground/30 flex items-center justify-center hover:border-muted-foreground/50">
                      <Circle class="h-2.5 w-2.5 text-muted-foreground/30" />
                    </div>
                  </button>
                  <div class="flex-1 min-w-0 overflow-hidden">
                    <h4 :class="['text-xs font-medium truncate', habit.completed_today && 'line-through text-muted-foreground']" :title="habit.name">{{ habit.name }}</h4>
                    <div class="flex items-center gap-1">
                      <span class="text-[9px] text-muted-foreground">{{ formatTimeReadable(habit.scheduled_time) }}</span>
                      <span v-if="habit.duration_minutes" class="text-[9px] text-muted-foreground">· {{ formatDuration(habit.duration_minutes) }}</span>
                    </div>
                  </div>
                  <div class="flex flex-col gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                    <Button 
                      v-if="!habit.completed_today"
                      variant="ghost" 
                      size="icon" 
                      class="h-4 w-4 text-orange-500 hover:text-orange-600 hover:bg-orange-500/10"
                      @click.stop="openSkipModal(habit)"
                      title="Skip with reason"
                    >
                      <Ban class="h-2 w-2" />
                    </Button>
                    <Button 
                      variant="ghost" 
                      size="icon" 
                      class="h-4 w-4 text-destructive"
                      @click.stop="handleDeleteHabit(habit.id)"
                    >
                      <Trash2 class="h-2 w-2" />
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>

      <!-- Close standalone inventories grid -->
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
                      {{ formatDuration(habit.duration_minutes) }}
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
                    :model-value="newHabit.scheduled_time ?? ''" 
                    @update:model-value="newHabit.scheduled_time = $event || null"
                    type="time"
                    placeholder="09:00"
                  />
                </div>
                <div>
                  <label class="text-sm font-medium mb-1.5 block">Duration (HH:MM)</label>
                  <Input 
                    :model-value="formatTimeForInput(newHabit.duration_minutes)" 
                    @update:model-value="newHabit.duration_minutes = parseDuration($event)"
                    type="text"
                    placeholder="00:30"
                  />
                </div>
              </div>

              <!-- Repetition Presets -->
              <div>
                <label class="text-sm font-medium mb-1.5 block">Repeats</label>
                <div class="flex gap-2">
                  <button
                    type="button"
                    class="flex-1 py-2 px-3 text-sm font-medium rounded-lg transition-all"
                    :class="getRepetitionMode(newHabit.days_of_week) === 'daily' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'"
                    @click="setRepetitionMode('daily', newHabit)"
                  >
                    Daily
                  </button>
                  <button
                    type="button"
                    class="flex-1 py-2 px-3 text-sm font-medium rounded-lg transition-all"
                    :class="getRepetitionMode(newHabit.days_of_week) === 'weekdays' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'"
                    @click="setRepetitionMode('weekdays', newHabit)"
                  >
                    Weekdays
                  </button>
                  <button
                    type="button"
                    class="flex-1 py-2 px-3 text-sm font-medium rounded-lg transition-all"
                    :class="getRepetitionMode(newHabit.days_of_week) === 'weekends' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'"
                    @click="setRepetitionMode('weekends', newHabit)"
                  >
                    Weekends
                  </button>
                  <button
                    type="button"
                    class="flex-1 py-2 px-3 text-sm font-medium rounded-lg transition-all"
                    :class="getRepetitionMode(newHabit.days_of_week) === 'custom' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'"
                    @click="setRepetitionMode('custom', newHabit)"
                  >
                    Custom
                  </button>
                </div>
              </div>

              <!-- Custom Days Selector (only when Custom is selected) -->
              <div v-if="getRepetitionMode(newHabit.days_of_week) === 'custom'">
                <label class="text-sm font-medium mb-1.5 block">Select Days</label>
                <div class="flex gap-1">
                  <button
                    v-for="(day, index) in weekDays"
                    :key="index"
                    type="button"
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

              <!-- Color -->
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
                  @update:model-value="editingHabit!.scheduled_time = $event || null"
                  placeholder="HH:MM"
                />
              </div>

              <!-- Duration -->
              <div>
                <label class="text-sm font-medium mb-1.5 block">Duration (HH:MM)</label>
                <Input 
                  type="text" 
                  :model-value="formatTimeForInput(editingHabit.duration_minutes)"
                  @update:model-value="editingHabit.duration_minutes = parseDuration($event)"
                  placeholder="00:30"
                />
              </div>

              <!-- Repetition Presets -->
              <div>
                <label class="text-sm font-medium mb-1.5 block">Repeats</label>
                <div class="flex gap-2">
                  <button
                    type="button"
                    class="flex-1 py-2 px-3 text-sm font-medium rounded-lg transition-all"
                    :class="getRepetitionMode(editingHabit.days_of_week || []) === 'daily' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'"
                    @click="setRepetitionMode('daily', editingHabit as any)"
                  >
                    Daily
                  </button>
                  <button
                    type="button"
                    class="flex-1 py-2 px-3 text-sm font-medium rounded-lg transition-all"
                    :class="getRepetitionMode(editingHabit.days_of_week || []) === 'weekdays' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'"
                    @click="setRepetitionMode('weekdays', editingHabit as any)"
                  >
                    Weekdays
                  </button>
                  <button
                    type="button"
                    class="flex-1 py-2 px-3 text-sm font-medium rounded-lg transition-all"
                    :class="getRepetitionMode(editingHabit.days_of_week || []) === 'weekends' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'"
                    @click="setRepetitionMode('weekends', editingHabit as any)"
                  >
                    Weekends
                  </button>
                  <button
                    type="button"
                    class="flex-1 py-2 px-3 text-sm font-medium rounded-lg transition-all"
                    :class="getRepetitionMode(editingHabit.days_of_week || []) === 'custom' ? 'bg-primary text-primary-foreground' : 'bg-secondary text-secondary-foreground hover:bg-secondary/80'"
                    @click="setRepetitionMode('custom', editingHabit as any)"
                  >
                    Custom
                  </button>
                </div>
              </div>

              <!-- Custom Days Selector (only when Custom is selected) -->
              <div v-if="getRepetitionMode(editingHabit.days_of_week || []) === 'custom'">
                <label class="text-sm font-medium mb-1.5 block">Select Days</label>
                <div class="flex gap-1">
                  <button
                    v-for="(day, index) in weekDays"
                    :key="index"
                    type="button"
                    :class="[
                      'flex-1 py-1.5 text-xs font-medium rounded transition-all',
                      (editingHabit.days_of_week || []).includes(index)
                        ? 'bg-primary text-primary-foreground'
                        : 'bg-secondary text-muted-foreground hover:bg-secondary/80'
                    ]"
                    @click="toggleDayOfWeek(index, editingHabit as any)"
                  >
                    {{ day }}
                  </button>
                </div>
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
              <div class="flex gap-2">
                <Button 
                  variant="destructive" 
                  @click="handleDeleteHabit(editingHabit.id); showEditModal = false"
                >
                  <Trash2 class="h-4 w-4 mr-1" />
                  Delete
                </Button>
                <Button @click="handleUpdateHabit">Save Changes</Button>
              </div>
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
                  class="p-3 bg-muted/30 rounded-lg space-y-3"
                >
                  <div class="flex items-center justify-between gap-2">
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
                      <Badge variant="secondary" class="text-[10px] h-4 px-1.5">
                        {{ inv.coverage_mode === 'whole_day' ? 'Whole Day' : 'Partial Day' }}
                      </Badge>
                    </div>
                    <button 
                      @click="habitsStore.deleteHabitInventory(inv.id)"
                      class="p-1.5 text-muted-foreground hover:text-destructive hover:bg-destructive/10 rounded transition-colors"
                    >
                      <Trash2 class="h-4 w-4" />
                    </button>
                  </div>

                  <!-- Coverage Mode Settings -->
                  <div class="flex items-center gap-3 pl-7">
                    <button
                      type="button"
                      class="flex items-center gap-1.5 px-2 py-1 rounded text-xs transition-colors"
                      :class="inv.coverage_mode === 'partial_day' || !inv.coverage_mode ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground hover:bg-muted/80'"
                      @click="handleUpdateCoverageMode(inv.id, 'partial_day')"
                    >
                      Partial Day
                    </button>
                    <button
                      type="button"
                      class="flex items-center gap-1.5 px-2 py-1 rounded text-xs transition-colors"
                      :class="inv.coverage_mode === 'whole_day' ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground hover:bg-muted/80'"
                      @click="handleUpdateCoverageMode(inv.id, 'whole_day')"
                    >
                      Whole Day
                    </button>
                  </div>

                  <!-- Day Start/End Time (for defining time range) -->
                  <div class="grid grid-cols-2 gap-2 pl-7">
                    <div>
                      <label class="text-[10px] text-muted-foreground block mb-0.5">Start Time</label>
                      <Input 
                        type="time"
                        :model-value="inv.day_start_time || ''"
                        @update:model-value="habitsStore.updateHabitInventory(inv.id, { day_start_time: $event || null })"
                        class="h-7 text-xs"
                      />
                    </div>
                    <div>
                      <label class="text-[10px] text-muted-foreground block mb-0.5">End Time</label>
                      <Input 
                        type="time"
                        :model-value="inv.day_end_time || ''"
                        @update:model-value="habitsStore.updateHabitInventory(inv.id, { day_end_time: $event || null })"
                        class="h-7 text-xs"
                      />
                    </div>
                  </div>

                  <!-- Linked Inventories (for whole_day mode) -->
                  <div v-if="inv.coverage_mode === 'whole_day'" class="pl-7">
                    <label class="text-[10px] text-muted-foreground block mb-1">Link Partial Day Sheets</label>
                    <div class="flex flex-wrap gap-1">
                      <button
                        v-for="other in habitsStore.habitInventories.filter(o => o.id !== inv.id && o.coverage_mode !== 'whole_day')"
                        :key="other.id"
                        type="button"
                        class="flex items-center gap-1 px-2 py-0.5 rounded text-[10px] transition-colors"
                        :class="(inv.linked_inventory_ids || []).includes(other.id) ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground hover:bg-muted/80'"
                        @click="() => {
                          const current = inv.linked_inventory_ids || []
                          const updated = current.includes(other.id) 
                            ? current.filter(id => id !== other.id)
                            : [...current, other.id]
                          habitsStore.updateHabitInventory(inv.id, { linked_inventory_ids: updated })
                        }"
                      >
                        <div class="w-2 h-2 rounded-full" :style="{ backgroundColor: other.color || '#10b981' }" />
                        {{ other.name }}
                      </button>
                      <span v-if="habitsStore.habitInventories.filter(o => o.id !== inv.id && o.coverage_mode !== 'whole_day').length === 0" class="text-[10px] text-muted-foreground italic">
                        No partial day sheets to link
                      </span>
                    </div>
                  </div>
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

