<script setup lang="ts">
import { Plus } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'

interface Props {
  adaptive?: boolean  // Use adaptive visibility (hover reveal on desktop)
  disabled?: boolean
  label?: string      // Text label (e.g., "Add Entry", "New Sheet")
}

const props = withDefaults(defineProps<Props>(), {
  adaptive: false,
  disabled: false
})

const emit = defineEmits<{ click: [e: Event] }>()

const isIconOnly = !props.label

const iconOnlyClasses = cn(
  // Dynamic sizing: 1.75em = scales with parent font size
  'h-[1.75em] w-[1.75em] min-h-[20px] min-w-[20px]',
  'flex items-center justify-center rounded transition-all shrink-0',
  'text-muted-foreground hover:text-primary hover:bg-primary/10',
  props.adaptive && 'sm:opacity-0 sm:group-hover:opacity-100',
  props.disabled && 'opacity-50 pointer-events-none'
)
</script>

<template>
  <!-- Icon-only mode with dynamic sizing -->
  <button
    v-if="isIconOnly"
    :class="iconOnlyClasses"
    :disabled="disabled"
    title="Add"
    @click="emit('click', $event)"
  >
    <Plus class="h-[0.9em] w-[0.9em]" />
  </button>
  
  <!-- Labeled button mode - uses standard Button component -->
  <Button
    v-else
    :disabled="disabled"
    :class="adaptive && 'sm:opacity-0 sm:group-hover:opacity-100'"
    @click="emit('click', $event)"
  >
    <Plus class="h-4 w-4 mr-1.5" />
    <span>{{ label }}</span>
  </Button>
</template>
