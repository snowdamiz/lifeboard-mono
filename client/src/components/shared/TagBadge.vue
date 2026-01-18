<script setup lang="ts">
import type { Tag } from '@/types'

interface Props {
  tag: Tag
  removable?: boolean
  clickable?: boolean
  size?: 'small' | 'medium' | 'large'
}

const props = withDefaults(defineProps<Props>(), {
  removable: false,
  clickable: false,
  size: 'small'
})

const emit = defineEmits<{
  (e: 'click', tag: Tag): void
  (e: 'remove', tag: Tag): void
}>()

function handleClick() {
  if (props.clickable) {
    emit('click', props.tag)
  }
}

function handleRemove(event: Event) {
  event.stopPropagation()
  emit('remove', props.tag)
}

const sizeClasses = {
  small: 'px-2 py-0.5 text-xs',
  medium: 'px-2.5 py-1 text-sm',
  large: 'px-3 py-1.5 text-base'
}
</script>

<template>
  <span
    class="tag-badge inline-flex items-center gap-1 rounded-full font-medium transition-all"
    :class="[
      sizeClasses[size],
      clickable ? 'cursor-pointer hover:ring-2 hover:ring-offset-1' : ''
    ]"
    :style="{
      backgroundColor: tag.color + '20',
      color: tag.color,
      borderColor: tag.color
    }"
    @click="handleClick"
  >
    <span class="tag-name">{{ tag.name }}</span>
    <button
      v-if="removable"
      type="button"
      class="tag-remove ml-0.5 rounded-full p-0.5 hover:bg-white/20 focus:outline-none"
      @click="handleRemove"
    >
      <svg class="h-3 w-3" viewBox="0 0 16 16" fill="currentColor">
        <path d="M5.28 4.22a.75.75 0 00-1.06 1.06L6.94 8l-2.72 2.72a.75.75 0 101.06 1.06L8 9.06l2.72 2.72a.75.75 0 101.06-1.06L9.06 8l2.72-2.72a.75.75 0 00-1.06-1.06L8 6.94 5.28 4.22z" />
      </svg>
    </button>
  </span>
</template>

<style scoped>
.tag-badge {
  border: 1px solid;
  border-color: inherit;
}
</style>
