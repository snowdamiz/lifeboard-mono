<script setup lang="ts">
/**
 * BaseIconButton - Unified icon button component
 * 
 * Replaces: AddButton, EditButton, DeleteButton, SettingsButton
 * 
 * Uses the useIconButton composable for consistent behavior:
 * - Dynamic sizing (scales with parent font)
 * - Adaptive visibility (hover reveal on desktop)
 * - Variant-based styling (default, destructive, success, outline)
 * - Loading state with spinner
 */
import { computed, type Component } from 'vue'
import { Loader2 } from 'lucide-vue-next'
import { useIconButton, type IconButtonVariant, ICON_SIZE_CLASS } from '@/composables/useIconButton'
import { cn } from '@/lib/utils'

interface Props {
  /** Icon component to display */
  icon: Component
  /** Enable adaptive visibility (fade on desktop until hover) */
  adaptive?: boolean
  /** Disable the button */
  disabled?: boolean
  /** Show loading spinner instead of icon */
  loading?: boolean
  /** Button variant for color styling */
  variant?: IconButtonVariant
  /** Tooltip/title text */
  title?: string
  /** Optional text label (shows full button mode) */
  label?: string
  /** data-testid for testing */
  testId?: string
}

const props = withDefaults(defineProps<Props>(), {
  adaptive: false,
  disabled: false,
  loading: false,
  variant: 'default',
  title: ''
})

const emit = defineEmits<{ click: [e: Event] }>()

const { buttonClasses, isDisabled, handleClick } = useIconButton({
  adaptive: props.adaptive,
  disabled: props.disabled,
  loading: props.loading,
  variant: props.variant
})

// For labeled buttons, use different styling
const labeledClasses = computed(() => cn(
  'inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md transition-all',
  'text-sm font-medium',
  props.variant === 'default' && 'text-foreground hover:bg-accent',
  props.variant === 'destructive' && 'text-destructive hover:bg-destructive/10',
  props.variant === 'success' && 'text-green-600 hover:bg-green-600/10',
  props.variant === 'outline' && 'border border-input hover:bg-accent',
  props.adaptive && 'sm:opacity-0 sm:group-hover:opacity-100',
  (props.disabled || props.loading) && 'opacity-50 pointer-events-none'
))

const onClick = (e: Event) => handleClick(e, () => emit('click', e))
</script>

<template>
  <!-- Icon-only mode -->
  <button
    v-if="!label"
    :class="buttonClasses"
    :disabled="isDisabled"
    :title="title"
    :data-testid="testId"
    @click="onClick"
  >
    <Loader2 v-if="loading" :class="[ICON_SIZE_CLASS, 'animate-spin']" />
    <component v-else :is="icon" :class="ICON_SIZE_CLASS" />
  </button>
  
  <!-- Labeled button mode -->
  <button
    v-else
    :class="labeledClasses"
    :disabled="isDisabled"
    :title="title"
    :data-testid="testId"
    @click="onClick"
  >
    <Loader2 v-if="loading" class="h-4 w-4 animate-spin" />
    <component v-else :is="icon" class="h-4 w-4" />
    <span>{{ label }}</span>
  </button>
</template>
