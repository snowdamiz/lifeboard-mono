<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Plus, X, PlusCircle, MinusCircle } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import type { Tag } from '@/types'
import { api } from '@/services/api'
import TagManager from '@/components/shared/TagManager.vue'

const props = defineProps<{
  modelValue: Tag[] // Currently applied tags
  placeholder?: string
}>()

const emit = defineEmits<{
  'update:modelValue': [tags: Tag[]],
  'tags-deleted': [ids: string[]] // Re-emit for parent refresh
}>()

const showDropdown = ref(false)
const tagManagerRef = ref<InstanceType<typeof TagManager> | null>(null)
const checkedTagIds = ref<Set<string>>(new Set())

// Tags applied to the item (for bolding in list)
const appliedTagIds = computed(() => new Set(props.modelValue.map(t => t.id)))

// Helper to close dropdown with delay (for click handling)
const hideDropdownDelayed = () => {
  setTimeout(() => {
    // Check if we're not interacting with the dropdown (e.g. clicking delete confirm)
    if (tagManagerRef.value?.showDeleteConfirm) return
    
    showDropdown.value = false
    checkedTagIds.value = new Set()
  }, 200)
}

// removeTag from item (X button on badge)
const removeTag = (tagId: string) => {
  const newTags = props.modelValue.filter(t => t.id !== tagId)
  emit('update:modelValue', newTags)
}

// Add checked tags to item
const addCheckedTags = () => {
  if (!tagManagerRef.value) return
  const allTags = tagManagerRef.value.allTags || []
  
  const tagsToAdd = allTags.filter((t: any) => checkedTagIds.value.has(t.id))
  // Merge with existing avoiding duplicates
  const existingIds = new Set(props.modelValue.map(t => t.id))
  const newTags = [...props.modelValue]
  
  tagsToAdd.forEach((tag: any) => {
    if (!existingIds.has(tag.id)) {
      newTags.push(tag)
    }
  })
  
  emit('update:modelValue', newTags)
  checkedTagIds.value = new Set()
  showDropdown.value = false
}

// Remove checked tags from item
const removeCheckedTags = () => {
  const idsToRemove = checkedTagIds.value
  const newTags = props.modelValue.filter(t => !idsToRemove.has(t.id))
  emit('update:modelValue', newTags)
  checkedTagIds.value = new Set()
  showDropdown.value = false
}

// Re-emit delete event
const handleTagsDeleted = (ids: string[]) => {
  emit('tags-deleted', ids)
  // Also remove from local applied tags if needed
  const newTags = props.modelValue.filter(t => !ids.includes(t.id))
  emit('update:modelValue', newTags)
}

</script>

<template>
  <div class="relative" :class="showDropdown ? 'pb-64' : ''">
    <!-- Selected Tags Display (Badges) -->
    <div class="flex flex-wrap gap-1.5 mb-2" v-if="modelValue.length > 0">
      <Badge
        v-for="tag in modelValue"
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
          @click="removeTag(tag.id)"
        >
          <X class="h-3 w-3" />
        </button>
      </Badge>
    </div>

    <!-- Trigger Button -->
    <Button
      variant="outline"
      class="w-full justify-start text-left font-normal"
      :class="!modelValue.length && 'text-muted-foreground'"
      @click="showDropdown = !showDropdown"
    >
      <Plus class="mr-2 h-4 w-4" />
      {{ modelValue.length > 0 ? 'Manage tags...' : 'Add tags...' }}
    </Button>

    <!-- Dropdown (Using TagManager) -->
    <div
      v-if="showDropdown"
      class="absolute z-50 mt-1 w-full border border-border rounded-lg shadow-lg overflow-hidden"
    >
      <!-- Red background applied here as requested -->
      <TagManager
        ref="tagManagerRef"
        v-model:checkedTagIds="checkedTagIds"
        :hide-input="false"
        :compact="true"
        :embedded="true"
        :applied-tag-ids="appliedTagIds"
        class="bg-card"
        @tags-deleted="handleTagsDeleted"
      >
        <template #actions="{ checkedCount, loading }">
          <Button
            type="button"
            variant="outline"
            size="sm"
            class="h-7 px-2 text-xs flex-1"
            :disabled="checkedCount === 0"
            @click="addCheckedTags"
            @mousedown.prevent
          >
            <PlusCircle class="h-3 w-3 mr-1" />
            Add
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            class="h-7 px-2 text-xs flex-1"
            :disabled="checkedCount === 0"
            @click="removeCheckedTags"
            @mousedown.prevent
          >
            <MinusCircle class="h-3 w-3 mr-1" />
            Remove
          </Button>
        </template>
      </TagManager>
    </div>
  </div>
</template>
