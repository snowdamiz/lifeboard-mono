<script setup lang="ts">
import { computed } from 'vue'
import { cn } from '@/lib/utils'

interface Props {
  modelValue?: string | number
  type?: string
  placeholder?: string
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  type: 'text',
  disabled: false
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const inputClasses = computed(() => cn(
  'flex h-10 w-full rounded-lg border border-input bg-background px-3.5 py-2 text-sm transition-all duration-150',
  'placeholder:text-muted-foreground/70',
  'hover:border-muted-foreground/30',
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:border-primary',
  'disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:border-input',
  'file:border-0 file:bg-transparent file:text-sm file:font-medium',
  props.class
))
</script>

<template>
  <input
    :type="type"
    :value="modelValue"
    :placeholder="placeholder"
    :disabled="disabled"
    :class="inputClasses"
    @input="emit('update:modelValue', ($event.target as HTMLInputElement).value)"
  />
</template>
