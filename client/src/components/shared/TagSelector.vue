<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { Plus, X, Check } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import type { Tag } from '@/types'
import { api } from '@/services/api'

interface Props {
  modelValue: Tag[]
  placeholder?: string
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: 'Add tags...'
})

const emit = defineEmits<{
  'update:modelValue': [tags: Tag[]]
}>()

const allTags = ref<Tag[]>([])
const showDropdown = ref(false)
const searchQuery = ref('')
const newTagName = ref('')
const showNewTagForm = ref(false)
const newTagColor = ref('#6366f1')

const tagColors = [
  '#6366f1', '#8b5cf6', '#ec4899', '#ef4444', '#f97316',
  '#eab308', '#22c55e', '#14b8a6', '#0ea5e9', '#64748b'
]

onMounted(async () => {
  const response = await api.listTags()
  allTags.value = response.data
})

const filteredTags = computed(() => {
  const selectedIds = props.modelValue.map(t => t.id)
  return allTags.value.filter(tag => 
    !selectedIds.includes(tag.id) &&
    tag.name.toLowerCase().includes(searchQuery.value.toLowerCase())
  )
})

const addTag = (tag: Tag) => {
  emit('update:modelValue', [...props.modelValue, tag])
  searchQuery.value = ''
}

const removeTag = (tagId: string) => {
  emit('update:modelValue', props.modelValue.filter(t => t.id !== tagId))
}

const createTag = async () => {
  if (!newTagName.value.trim()) return
  
  try {
    const response = await api.createTag({
      name: newTagName.value.trim(),
      color: newTagColor.value
    })
    allTags.value.push(response.data)
    addTag(response.data)
    newTagName.value = ''
    showNewTagForm.value = false
  } catch (e) {
    console.error('Failed to create tag:', e)
  }
}

const hideDropdownDelayed = () => {
  setTimeout(() => {
    showDropdown.value = false
  }, 200)
}
</script>

<template>
  <div class="relative">
    <!-- Selected Tags -->
    <div class="flex flex-wrap gap-1.5 mb-2" v-if="modelValue.length > 0">
      <Badge
        v-for="tag in modelValue"
        :key="tag.id"
        :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
        variant="outline"
        class="gap-1 pr-1"
      >
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

    <!-- Tag Input -->
    <div class="relative">
      <Input
        v-model="searchQuery"
        :placeholder="placeholder"
        class="pr-8"
        @focus="showDropdown = true"
        @blur="hideDropdownDelayed"
      />
      <Button
        type="button"
        variant="ghost"
        size="icon"
        class="absolute right-1 top-1/2 -translate-y-1/2 h-7 w-7"
        @click="showNewTagForm = !showNewTagForm"
      >
        <Plus class="h-4 w-4" />
      </Button>
    </div>

    <!-- New Tag Form -->
    <div v-if="showNewTagForm" class="mt-2 p-3 border border-border rounded-lg bg-secondary/30 space-y-2">
      <p class="text-xs font-medium text-muted-foreground">Create new tag</p>
      <Input
        v-model="newTagName"
        placeholder="Tag name"
        class="h-8 text-sm"
        @keydown.enter.prevent="createTag"
      />
      <div class="flex items-center gap-1.5">
        <button
          v-for="color in tagColors"
          :key="color"
          type="button"
          class="h-5 w-5 rounded-full transition-transform hover:scale-110 flex items-center justify-center"
          :style="{ backgroundColor: color }"
          @click="newTagColor = color"
        >
          <Check v-if="newTagColor === color" class="h-3 w-3 text-white" />
        </button>
      </div>
      <div class="flex gap-2">
        <Button type="button" size="sm" variant="outline" class="h-7 text-xs" @click="showNewTagForm = false">
          Cancel
        </Button>
        <Button type="button" size="sm" class="h-7 text-xs" :disabled="!newTagName.trim()" @click="createTag">
          Create
        </Button>
      </div>
    </div>

    <!-- Dropdown -->
    <div
      v-if="showDropdown && filteredTags.length > 0"
      class="absolute z-10 mt-1 w-full max-h-48 overflow-auto bg-card border border-border rounded-lg shadow-lg"
    >
      <button
        v-for="tag in filteredTags"
        :key="tag.id"
        type="button"
        class="w-full px-3 py-2 text-left text-sm hover:bg-secondary/60 flex items-center gap-2 transition-colors"
        @mousedown.prevent="addTag(tag)"
      >
        <div 
          class="h-3 w-3 rounded-full shrink-0" 
          :style="{ backgroundColor: tag.color }"
        />
        {{ tag.name }}
      </button>
    </div>
  </div>
</template>

