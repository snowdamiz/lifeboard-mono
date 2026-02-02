<script setup lang="ts">
/**
 * ClickableCard - Standardized clickable card with proper event handling
 * 
 * This component solves the problem of buttons inside clickable cards not working
 * because click events bubble up to the parent. It provides:
 * 1. A main click handler for the card
 * 2. An actions slot that automatically stops propagation
 * 
 * Usage:
 *   <ClickableCard @click="navigateToDetail">
 *     <template #default>Card content here</template>
 *     <template #actions>
 *       <EditButton @click="edit" />
 *       <DeleteButton @click="delete" />
 *     </template>
 *   </ClickableCard>
 */
import { Card } from '@/components/ui/card'
import { cn } from '@/lib/utils'

interface Props {
  class?: string
  disabled?: boolean
  // Whether to show the actions container (defaults to hover-only on desktop)
  actionsAlwaysVisible?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false,
  actionsAlwaysVisible: false
})

const emit = defineEmits<{
  click: [e: MouseEvent]
}>()

const handleCardClick = (e: MouseEvent) => {
  if (props.disabled) return
  emit('click', e)
}

const stopPropagation = (e: Event) => {
  e.stopPropagation()
}
</script>

<template>
  <Card
    :class="cn(
      'group transition-all',
      !disabled && 'cursor-pointer hover:border-primary/50 hover:shadow-md',
      disabled && 'opacity-60 cursor-not-allowed',
      props.class
    )"
    @click="handleCardClick"
  >
    <div class="flex items-start gap-3 p-4">
      <!-- Main content slot -->
      <div class="flex-1 min-w-0">
        <slot />
      </div>

      <!-- Actions slot - automatically stops propagation -->
      <div 
        v-if="$slots.actions"
        :class="cn(
          'flex items-center gap-1 shrink-0 transition-opacity',
          !actionsAlwaysVisible && 'opacity-0 group-hover:opacity-100'
        )"
        @click="stopPropagation"
      >
        <slot name="actions" />
      </div>
    </div>
  </Card>
</template>
