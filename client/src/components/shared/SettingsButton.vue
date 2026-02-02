<script setup lang="ts">
import { Settings } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'

interface Props {
  disabled?: boolean
  label?: string      // Text label (e.g., "Settings", "Manage Sources")
  iconOnly?: boolean  // Force icon-only mode
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false,
  iconOnly: false
})

const emit = defineEmits<{ click: [e: Event] }>()

const showLabel = props.label && !props.iconOnly
</script>

<template>
  <Button
    variant="outline"
    :size="iconOnly ? 'icon' : 'default'"
    :disabled="disabled"
    @click="emit('click', $event)"
  >
    <Settings :class="['h-4 w-4', showLabel && 'sm:mr-2']" />
    <span v-if="showLabel" class="hidden sm:inline">{{ label }}</span>
  </Button>
</template>
