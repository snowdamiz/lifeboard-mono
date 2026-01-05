<script setup lang="ts">
import { computed } from 'vue'
import { cn } from '@/lib/utils'
import { Check } from 'lucide-vue-next'

interface Props {
  modelValue?: boolean
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: false,
  disabled: false
})

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
}>()

const toggle = () => {
  if (!props.disabled) {
    emit('update:modelValue', !props.modelValue)
  }
}

const checkboxClasses = computed(() => cn(
  'h-5 w-5 shrink-0 rounded border border-primary shadow focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 flex items-center justify-center',
  props.modelValue && 'bg-primary text-primary-foreground',
  props.class
))
</script>

<template>
  <!-- Larger clickable area wrapper -->
  <button
    type="button"
    role="checkbox"
    :aria-checked="modelValue"
    :disabled="disabled"
    class="p-2 -m-2 cursor-pointer flex items-center justify-center"
    @click="toggle"
  >
    <span :class="checkboxClasses">
      <Check v-if="modelValue" class="h-3.5 w-3.5" />
    </span>
  </button>
</template>

