<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { Filter, X } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import TagManager from '@/components/shared/TagManager.vue'
import { useTagsStore } from '@/stores/tags'

interface Props {
  modelValue: Set<string> | string[]
  title?: string
  description?: string
  showActiveFilters?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  title: 'Filter',
  description: 'Select tags to filter by',
  showActiveFilters: true
})

const emit = defineEmits<{
  'update:model-value': [value: Set<string>]
  apply: []
  clear: []
}>()

const tagsStore = useTagsStore()
const isOpen = ref(false)
const checkedTagIds = ref<Set<string>>(new Set())

// Sync from modelValue
watch(() => props.modelValue, (newVal) => {
  checkedTagIds.value = newVal instanceof Set ? new Set(newVal) : new Set(newVal)
}, { immediate: true })

const activeFilterCount = computed(() => {
  return props.modelValue instanceof Set ? props.modelValue.size : props.modelValue.length
})

const activeTagIds = computed(() => {
  return props.modelValue instanceof Set ? Array.from(props.modelValue) : props.modelValue
})

const getTagName = (tagId: string) => {
  return tagsStore.tags.find(t => t.id === tagId)?.name || 'Tag'
}

const getTagColor = (tagId: string) => {
  return tagsStore.tags.find(t => t.id === tagId)?.color
}

const applyFilters = () => {
  emit('update:model-value', new Set(checkedTagIds.value))
  emit('apply')
  isOpen.value = false
}

const clearFilters = () => {
  checkedTagIds.value = new Set()
  emit('update:model-value', new Set())
  emit('clear')
  isOpen.value = false
}

const removeTag = (tagId: string) => {
  const newSet = new Set(props.modelValue instanceof Set ? props.modelValue : props.modelValue)
  newSet.delete(tagId)
  emit('update:model-value', newSet)
  emit('apply')
}
</script>

<template>
  <div class="relative">
    <!-- Trigger Button -->
    <Button 
      variant="outline" 
      size="sm" 
      class="h-9 relative" 
      :class="{ 'border-primary text-primary': activeFilterCount > 0 }"
      @click="isOpen = !isOpen"
    >
      <Filter class="h-4 w-4 sm:mr-2" />
      <span class="hidden sm:inline">Filter</span>
      <Badge 
        v-if="activeFilterCount > 0" 
        variant="secondary" 
        class="ml-2 h-5 min-w-[20px] px-1 bg-primary text-primary-foreground hover:bg-primary/90"
      >
        {{ activeFilterCount }}
      </Badge>
    </Button>

    <!-- Dropdown Panel -->
    <div 
      v-if="isOpen" 
      class="absolute right-0 top-full mt-2 w-72 bg-popover text-popover-foreground border rounded-lg shadow-lg z-50 overflow-hidden"
    >
      <!-- Header -->
      <div class="p-2.5 border-b flex items-center justify-between">
        <div>
          <h4 class="text-sm font-medium leading-none">{{ title }}</h4>
          <p class="text-[11px] text-muted-foreground mt-1">{{ description }}</p>
        </div>
        <button 
          v-if="activeFilterCount > 0" 
          class="text-[11px] text-primary hover:underline" 
          @click="clearFilters"
        >
          Clear all
        </button>
      </div>
      
      <!-- Tag List - compact with max-height -->
      <div class="p-2 max-h-[200px] overflow-auto">
        <TagManager
          v-model:checkedTagIds="checkedTagIds"
          mode="select"
          embedded
          compact
          hide-input
        />
      </div>
      
      <!-- Footer -->
      <div class="p-2 border-t bg-muted/20 flex justify-between gap-2">
        <Button variant="ghost" size="sm" class="h-7 text-xs" @click="clearFilters" :disabled="activeFilterCount === 0">
          Clear
        </Button>
        <Button size="sm" class="h-7 text-xs" @click="applyFilters">
          Apply
        </Button>
      </div>
    </div>

    <!-- Backdrop -->
    <div v-if="isOpen" class="fixed inset-0 z-40 bg-transparent" @click="isOpen = false" />
  </div>

  <!-- Active Filters Display -->
  <div v-if="showActiveFilters && activeFilterCount > 0" class="flex flex-wrap gap-1.5 items-center mt-3">
    <span class="text-[11px] text-muted-foreground">Filters:</span>
    <Badge 
      v-for="tagId in activeTagIds" 
      :key="tagId"
      variant="secondary"
      class="gap-1 pl-1.5 pr-0.5 py-0 h-5 text-[10px]"
      :style="getTagColor(tagId) ? { backgroundColor: getTagColor(tagId) + '20', color: getTagColor(tagId) } : {}"
    >
      <span class="truncate max-w-[80px]">{{ getTagName(tagId) }}</span>
      <button 
        class="h-4 w-4 rounded-full hover:bg-black/10 flex items-center justify-center"
        @click.stop="removeTag(tagId)"
      >
        <X class="h-2.5 w-2.5" />
      </button>
    </Badge>
    <button class="text-[11px] text-muted-foreground hover:text-primary" @click="clearFilters">
      Clear all
    </button>
  </div>
</template>
