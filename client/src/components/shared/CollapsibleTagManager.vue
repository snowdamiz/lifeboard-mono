<script setup lang="ts">
import { ref, watch } from 'vue'
import { X, PlusCircle, MinusCircle } from 'lucide-vue-next'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import TagManager from '@/components/shared/TagManager.vue'
import type { Tag } from '@/types'

interface Props {
  appliedTagIds: string[] | Set<string>
  tags: Tag[] // For displaying selected tags
  resetTrigger?: boolean // Optional trigger to reset expansion
}

const props = withDefaults(defineProps<Props>(), {
  resetTrigger: false
})

const emit = defineEmits<{
  'add-tags': [tagIds: Set<string>]
  'remove-tag': [tagId: string]
}>()

const isExpanded = ref(false)
const tempSelectedTags = ref<Set<string>>(new Set())

const addCheckedTags = () => {
  emit('add-tags', tempSelectedTags.value)
  tempSelectedTags.value = new Set()
}

const removeCheckedTags = () => {
  const tagsToRemove = new Set(tempSelectedTags.value)
  tagsToRemove.forEach(tagId => emit('remove-tag', tagId))
  tempSelectedTags.value = new Set()
}

const removeTag = (tagId: string) => {
  emit('remove-tag', tagId)
}

// Watch resetTrigger to collapse when modal closes
watch(() => props.resetTrigger, () => {
  isExpanded.value = false
  tempSelectedTags.value = new Set()
})
</script>

<template>
  <div>
    <label class="text-sm font-medium mb-1.5 block">Tags</label>
    
    <!-- Selected Tags List -->
    <div class="flex flex-wrap gap-1.5 mb-2" v-if="tags.length > 0">
      <Badge
        v-for="tag in tags"
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

    <!-- Collapsed state: click to expand -->
    <div v-if="!isExpanded">
      <Input 
        placeholder="Click to manage tags..." 
        readonly
        @click="isExpanded = true"
        class="cursor-pointer"
      />
    </div>

    <!-- Expanded state: full TagManager -->
    <div v-else>
      <TagManager
        v-model:checkedTagIds="tempSelectedTags"
        :applied-tag-ids="appliedTagIds"
        mode="select"
        embedded
      >
        <template #actions="{ checkedCount }">
          <Button
            type="button"
            variant="outline"
            size="sm"
            class="h-7 px-2 text-xs flex-1"
            :disabled="checkedCount === 0"
            @click="addCheckedTags"
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
          >
            <MinusCircle class="h-3 w-3 mr-1" />
            Remove
          </Button>
        </template>
      </TagManager>
    </div>
  </div>
</template>
