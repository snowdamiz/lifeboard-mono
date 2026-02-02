<script setup lang="ts">
import { Edit2 } from 'lucide-vue-next'
import { cn } from '@/lib/utils'

interface Props {
  adaptive?: boolean  // Use adaptive visibility (hover reveal on desktop)
  disabled?: boolean
  title?: string
}

const props = withDefaults(defineProps<Props>(), {
  adaptive: true,
  disabled: false,
  title: 'Edit'
})

const emit = defineEmits<{ click: [e: Event] }>()

const buttonClasses = cn(
  // Dynamic sizing: 1.75em = scales with parent font size
  'h-[1.75em] w-[1.75em] min-h-[20px] min-w-[20px]',
  'flex items-center justify-center rounded transition-all shrink-0',
  'text-muted-foreground hover:text-primary hover:bg-primary/10',
  props.adaptive && 'sm:opacity-0 sm:group-hover:opacity-100',
  props.disabled && 'opacity-50 pointer-events-none'
)

const handleClick = (e: Event) => {
  e.stopPropagation()
  emit('click', e)
}
</script>

<template>
  <button
    :class="buttonClasses"
    :disabled="disabled"
    :title="title"
    @click="handleClick"
  >
    <Edit2 class="h-[0.9em] w-[0.9em]" />
  </button>
</template>
