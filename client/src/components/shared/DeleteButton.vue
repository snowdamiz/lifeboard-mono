<script setup lang="ts">
import { Trash2, Loader2 } from 'lucide-vue-next'
import { cn } from '@/lib/utils'

interface Props {
  adaptive?: boolean  // Use adaptive visibility (hover reveal on desktop)
  disabled?: boolean
  loading?: boolean   // Show spinner for async operations
  title?: string
}

const props = withDefaults(defineProps<Props>(), {
  adaptive: true,
  disabled: false,
  loading: false,
  title: 'Delete'
})

const emit = defineEmits<{ click: [e: Event] }>()

const buttonClasses = cn(
  // Dynamic sizing: 1.75em = scales with parent font size
  // On a 16px base, this is 28px. On 12px text, it's 21px. On 10px text, it's 17.5px
  'h-[1.75em] w-[1.75em] min-h-[20px] min-w-[20px]',
  'flex items-center justify-center rounded transition-all shrink-0',
  'text-muted-foreground hover:text-destructive hover:bg-destructive/10 active:text-destructive',
  props.adaptive && 'sm:opacity-0 sm:group-hover:opacity-100',
  (props.disabled || props.loading) && 'opacity-50 pointer-events-none'
)

const handleClick = (e: Event) => {
  e.stopPropagation()
  if (!props.loading) {
    emit('click', e)
  }
}
</script>

<template>
  <button
    :class="buttonClasses"
    :disabled="disabled || loading"
    :title="title"
    @click="handleClick"
  >
    <!-- Show spinner when loading, otherwise show trash icon -->
    <Loader2 v-if="loading" class="h-[0.9em] w-[0.9em] animate-spin" />
    <Trash2 v-else class="h-[0.9em] w-[0.9em]" />
  </button>
</template>
