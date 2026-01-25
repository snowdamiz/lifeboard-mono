<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Plus, Trash2, Check, PlusCircle, MinusCircle } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Checkbox } from '@/components/ui/checkbox'
import { api } from '@/services/api'
import { useTagsStore } from '@/stores/tags'
import type { Tag } from '@/types'

// Props to make it adaptable
interface Props {
  embedded?: boolean // If true, removes outer padding/layout
  compact?: boolean // If true, adjusts for smaller spaces (like dropdowns)
  mode?: 'manage' | 'select' // 'manage' = just manage tags, 'select' = manage + selection for parent
  hideInput?: boolean // If true, uses external search query
  searchQuery?: string // External search query
  appliedTagIds?: string[] | Set<string> // IDs of tags that are "applied" to the item (bolded)
  checkedTagIds?: Set<string> // Controlled checked state
}

const props = withDefaults(defineProps<Props>(), {
  embedded: false,
  compact: false,
  mode: 'manage',
  hideInput: false,
  searchQuery: '',
  appliedTagIds: () => [],
  checkedTagIds: () => new Set()
})

// Definition of TagData to match API response
interface TagData {
  id: string
  name: string
  color: string
}

interface TagUsageInfo {
  tag: TagData
  usage: {
    tasks: number
    goals: number
    pages: number
    habits: number
    inventory_items: number
    budget_sources: number
    total: number
  }
}


const tagsStore = useTagsStore()
const loading = computed(() => tagsStore.loading)
const allTags = computed(() => tagsStore.tags)
// internalSearchQuery used if hideInput is false
const useRegex = ref(false)
// Sync with prop if provided, else local
const checkedTagIds = ref<Set<string>>(props.checkedTagIds ? new Set(props.checkedTagIds) : new Set())

import { watch } from 'vue'
watch(() => props.checkedTagIds, (newVal) => {
  if (newVal) {
    checkedTagIds.value = new Set(newVal)
  }
}, { deep: true })

// Delete confirmation state
const showDeleteConfirm = ref(false)
const tagUsageInfo = ref<Record<string, TagUsageInfo>>({})
const loadingUsage = ref(false)
const deletingTags = ref(false)

const emit = defineEmits<{
  'update:modelValue': [tags: TagData[]], // If passing selection back
  'update:checkedTagIds': [ids: Set<string>],
  'tags-deleted': [ids: string[]]
}>()

const internalSearchQuery = ref('')
const effectiveSearchQuery = computed(() => props.hideInput ? props.searchQuery : internalSearchQuery.value)

onMounted(async () => {
  await fetchTags()
})

const fetchTags = async () => {
  if (tagsStore.tags.length === 0) {
    await tagsStore.fetchTags()
  }
}

// Filtered tags based on search
const filteredTags = computed(() => {
  if (!effectiveSearchQuery.value.trim()) return allTags.value
  
  if (useRegex.value) {
    try {
      const regex = new RegExp(effectiveSearchQuery.value, 'i')
      return allTags.value.filter(tag => regex.test(tag.name))
    } catch (e) {
      // Invalid regex, fall back to simple search
      return allTags.value.filter(tag =>
        tag.name.toLowerCase().includes(effectiveSearchQuery.value.toLowerCase())
      )
    }
  }
  
  return allTags.value.filter(tag =>
    tag.name.toLowerCase().includes(effectiveSearchQuery.value.toLowerCase())
  )
})

// Check if the search query can create a new tag (unique name)
const canCreateNewTag = computed(() => {
  if (!effectiveSearchQuery.value.trim()) return false
  const queryLower = effectiveSearchQuery.value.toLowerCase().trim()
  return !allTags.value.some(t => t.name.toLowerCase() === queryLower)
})

// Handle Enter key on search field - create tag or select first match
const handleSearchEnter = async () => {
  if (canCreateNewTag.value) {
    // Create new tag with the search query name
    try {
      const newTag = await tagsStore.createTag({
        name: effectiveSearchQuery.value.trim(),
        color: '#64748b' // Default gray
      })
      // allTags updates automatically via store
      if (!props.hideInput) internalSearchQuery.value = ''
    } catch (e) {
      console.error('Failed to create tag:', e)
    }
  } else if (filteredTags.value.length > 0) {
    // Toggle first matching tag's checkbox
    toggleTagChecked(filteredTags.value[0].id)
  }
}

// Check if a tag is checked
const isTagChecked = (tagId: string) => {
  return checkedTagIds.value.has(tagId)
}

// Number of checked tags
const checkedCount = computed(() => checkedTagIds.value.size)

// Are all filtered tags checked?
const allChecked = computed(() => {
  if (filteredTags.value.length === 0) return false
  return filteredTags.value.every(t => checkedTagIds.value.has(t.id))
})

// Toggle a single tag's checked state
const toggleTagChecked = (tagId: string) => {
  const newSet = new Set(checkedTagIds.value)
  if (newSet.has(tagId)) {
    newSet.delete(tagId)
  } else {
    newSet.add(tagId)
  }
  checkedTagIds.value = newSet
  emit('update:checkedTagIds', newSet)
}

// Toggle all filtered tags
const toggleAllChecked = () => {
  if (allChecked.value) {
    const newSet = new Set(checkedTagIds.value)
    filteredTags.value.forEach(t => newSet.delete(t.id))
    checkedTagIds.value = newSet
    emit('update:checkedTagIds', newSet)
  } else {
    const newSet = new Set(checkedTagIds.value)
    filteredTags.value.forEach(t => newSet.add(t.id))
    checkedTagIds.value = newSet
    emit('update:checkedTagIds', newSet)
  }
}

// Check tag usage before delete
const initiateDelete = async () => {
  if (checkedCount.value === 0) return
  
  loadingUsage.value = true
  tagUsageInfo.value = {}
  
  try {
    for (const tagId of Array.from(checkedTagIds.value)) {
      const tag = allTags.value.find(t => t.id === tagId)
      if (!tag) continue
      
      try {
        const response = await api.getTagItems(tagId)
        const data = response.data
        const items = data.items || data
        const usage = {
          tasks: items.tasks?.length || 0,
          goals: items.goals?.length || 0,
          pages: items.pages?.length || 0,
          habits: items.habits?.length || 0,
          inventory_items: items.inventory_items?.length || 0,
          budget_sources: items.budget_sources?.length || 0,
          total: 0
        }
        usage.total = Object.values(usage).reduce((a, b) => a + b, 0)
        
        tagUsageInfo.value[tagId] = { tag, usage }
      } catch (e) {
        console.error('Failed to get tag items for', tagId, e)
        tagUsageInfo.value[tagId] = { 
          tag, 
          usage: { 
            tasks: 0, goals: 0, pages: 0, habits: 0, inventory_items: 0, budget_sources: 0, total: 0 
          }
        }
      }
    }
    showDeleteConfirm.value = true
  } catch (e) {
    console.error('Failed to check tag usage:', e)
    showDeleteConfirm.value = true
  } finally {
    loadingUsage.value = false
  }
}

// Confirm and delete tags
const confirmDelete = async () => {
  deletingTags.value = true
  try {
    const idsToDelete = Array.from(checkedTagIds.value)
    for (const tagId of idsToDelete) {
      await tagsStore.deleteTag(tagId)
    }
    checkedTagIds.value = new Set()
    showDeleteConfirm.value = false
    tagUsageInfo.value = {}
    emit('tags-deleted', idsToDelete)
  } catch (e) {
    console.error('Failed to delete tags:', e)
  } finally {
    deletingTags.value = false
  }
}

const cancelDelete = () => {
  showDeleteConfirm.value = false
  tagUsageInfo.value = {}
}

const totalUsage = computed(() => {
  return Object.values(tagUsageInfo.value).reduce((sum, info) => sum + info.usage.total, 0)
})

const isTagApplied = (tagId: string) => {
  if (Array.isArray(props.appliedTagIds)) {
    return props.appliedTagIds.includes(tagId)
  }
  return props.appliedTagIds?.has(tagId) ?? false
}

// Expose methods for parent
defineExpose({
  handleSearchEnter,
  canCreateNewTag,
  toggleAllChecked,
  initiateDelete,
  checkedCount,
  allChecked,
  allTags,
  showDeleteConfirm
})
</script>

<template>
  <div :class="embedded ? '' : 'min-h-screen bg-background p-4 md:p-6'">
    <div :class="embedded ? '' : 'max-w-2xl mx-auto'">
      <!-- Search and Create -->
      <div class="space-y-2 mb-4">
        <div class="flex gap-2" v-if="!hideInput">
          <Input
            v-model="internalSearchQuery"
            placeholder="Search tags..."
            class="flex-1"
            :class="compact ? 'h-8 text-sm' : ''"
          />
        </div>
        <div v-if="false" class="flex items-center justify-between px-1">
          <span v-if="canCreateNewTag" class="text-xs text-primary">
            Press Enter to create
          </span>
        </div>
      </div>

      <!-- Tags List Card -->
      <div class="border border-border rounded-lg bg-card overflow-hidden">
        <!-- Header with Select All and Delete -->
        <div class="sticky top-0 bg-card border-b border-border">
          <!-- Select All Row -->
          <button
            type="button"
            class="w-full flex items-center gap-3 px-4 py-3 hover:bg-secondary/60 transition-colors"
            :class="compact ? 'px-3 py-2' : ''"
            @click="toggleAllChecked"
          >
            <Checkbox 
              :model-value="allChecked"
              class="pointer-events-none"
            />
            <span class="text-sm text-muted-foreground flex-1 text-left" :class="compact ? 'text-xs' : ''">
              {{ allChecked ? 'Deselect all' : 'Select all' }}
            </span>
            <span v-if="checkedCount > 0" class="font-medium text-primary" :class="compact ? 'text-xs' : 'text-sm'">
              {{ checkedCount }} selected
            </span>
          </button>
          
          
          <!-- Optional Slot for Action Buttons (Add/Remove) -->
          <slot name="actions" :checked-count="checkedCount" :loading="loadingUsage"></slot>

          <!-- Delete Button -->
          <div class="flex items-center gap-2 px-4 py-2 border-t border-border bg-secondary/30" :class="compact ? 'px-3 py-1.5' : ''">
            <span class="text-muted-foreground flex-1" :class="compact ? 'text-xs' : 'text-sm'">
              {{ allTags.length }} tag{{ allTags.length !== 1 ? 's' : '' }} total
            </span>
            <Button
              variant="outline"
              size="sm"
              class="text-destructive hover:text-destructive hover:bg-destructive/10"
              :class="compact ? 'h-7 text-xs' : ''"
              :disabled="checkedCount === 0 || loadingUsage"
              @click="initiateDelete"
            >
              <Trash2 class="h-4 w-4 mr-1" />
              {{ loadingUsage ? 'Loading...' : 'Delete Selected' }}
            </Button>
          </div>
        </div>

        <!-- Loading state -->
        <div v-if="loading" class="text-center text-muted-foreground" :class="compact ? 'px-3 py-4 text-xs' : 'px-4 py-8 text-sm'">
          Loading tags...
        </div>
        
        <!-- Tags list with checkboxes -->
        <div v-else-if="filteredTags.length > 0" class="divide-y divide-border" :class="compact ? 'max-h-60 overflow-auto' : ''">
          <button
            v-for="tag in filteredTags"
            :key="tag.id"
            type="button"
            class="w-full px-4 py-3 text-left hover:bg-secondary/60 flex items-center gap-3 transition-colors"
            :class="compact ? 'px-3 py-2' : ''"
            @click="toggleTagChecked(tag.id)"
          >
            <Checkbox 
              :model-value="isTagChecked(tag.id)"
              class="pointer-events-none"
            />
            <div 
              class="h-4 w-4 rounded-full shrink-0" 
              :style="{ backgroundColor: tag.color }"
            />
            <span class="flex-1 font-medium" :class="compact ? 'text-sm' : ''">
              {{ tag.name }}
            </span>
          </button>
        </div>
        
        <!-- Empty state -->
        <div v-else class="text-center text-muted-foreground" :class="compact ? 'px-3 py-4 text-xs' : 'px-4 py-8 text-sm'">
          {{ searchQuery ? 'No matching tags found' : 'No tags yet. Create one to get started!' }}
        </div>
      </div>
    </div>

    <!-- Delete Confirmation Modal -->
    <Teleport to="body">
      <div 
        v-if="showDeleteConfirm"
        class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-center justify-center p-4"
        @click="cancelDelete"
      >
        <div 
          class="w-full max-w-md bg-card border border-border rounded-xl shadow-xl p-4 space-y-4"
          @click.stop
        >
          <h3 class="text-lg font-semibold text-destructive flex items-center gap-2">
            <Trash2 class="h-5 w-5" />
            Delete {{ checkedCount }} Tag{{ checkedCount > 1 ? 's' : '' }}?
          </h3>
          
          <div v-if="totalUsage > 0" class="p-3 bg-destructive/10 border border-destructive/20 rounded-lg">
            <p class="text-sm font-medium text-destructive mb-2">
              ⚠️ Warning: These tags are used in {{ totalUsage }} item(s)
            </p>
            <div class="space-y-2 max-h-40 overflow-auto">
              <div 
                v-for="(info, tagId) in tagUsageInfo" 
                :key="tagId"
                class="text-xs"
              >
                <div class="flex items-center gap-2 mb-1">
                  <div 
                    class="h-2.5 w-2.5 rounded-full" 
                    :style="{ backgroundColor: info.tag.color }"
                  />
                  <span class="font-medium">{{ info.tag.name }}</span>
                  <span class="text-muted-foreground">({{ info.usage.total }} items)</span>
                </div>
                <div class="ml-4 text-muted-foreground">
                  <span v-if="info.usage.tasks">{{ info.usage.tasks }} tasks, </span>
                  <span v-if="info.usage.goals">{{ info.usage.goals }} goals, </span>
                  <span v-if="info.usage.habits">{{ info.usage.habits }} habits, </span>
                  <span v-if="info.usage.pages">{{ info.usage.pages }} notes, </span>
                  <span v-if="info.usage.inventory_items">{{ info.usage.inventory_items }} inventory items, </span>
                  <span v-if="info.usage.budget_sources">{{ info.usage.budget_sources }} budget sources</span>
                </div>
              </div>
            </div>
          </div>
          
          <div v-else class="text-sm text-muted-foreground">
            These tags are not used by any items.
          </div>
          
          <p class="text-sm text-muted-foreground">
            This action cannot be undone. The tag{{ checkedCount > 1 ? 's' : '' }} will be removed from all items.
          </p>
          
          <div class="flex gap-3 pt-2">
            <Button variant="outline" class="flex-1" @click="cancelDelete">
              Cancel
            </Button>
            <Button 
              variant="destructive" 
              class="flex-1" 
              :disabled="deletingTags"
              @click="confirmDelete"
            >
              {{ deletingTags ? 'Deleting...' : `Delete ${checkedCount} Tag${checkedCount > 1 ? 's' : ''}` }}
            </Button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
