<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { Calendar } from 'lucide-vue-next'
import { cn } from '@/lib/utils'

interface Props {
  modelValue?: string
  placeholder?: string
  disabled?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  disabled: false
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const inputRef = ref<HTMLInputElement | null>(null)
const displayValue = ref(formatForDisplay(props.modelValue))

// Watch for external model value changes
watch(() => props.modelValue, (newVal) => {
  displayValue.value = formatForDisplay(newVal)
})

// Format YYYY-MM-DD to MM/DD/YYYY for display
function formatForDisplay(isoDate: string | undefined): string {
  if (!isoDate) return ''
  const match = isoDate.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (match) {
    return `${match[2]}/${match[3]}/${match[1]}`
  }
  return isoDate
}

// Parse various input formats to YYYY-MM-DD
function parseToISODate(input: string): string | null {
  if (!input) return null
  
  // Remove all non-digit characters for parsing
  const digitsOnly = input.replace(/\D/g, '')
  
  // Handle MMDDYYYY (8 digits)
  if (digitsOnly.length === 8) {
    const month = digitsOnly.slice(0, 2)
    const day = digitsOnly.slice(2, 4)
    const year = digitsOnly.slice(4, 8)
    if (isValidDate(year, month, day)) {
      return `${year}-${month}-${day}`
    }
  }
  
  // Handle MM/DD/YYYY or MM-DD-YYYY
  const slashMatch = input.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/)
  if (slashMatch) {
    const month = slashMatch[1].padStart(2, '0')
    const day = slashMatch[2].padStart(2, '0')
    const year = slashMatch[3]
    if (isValidDate(year, month, day)) {
      return `${year}-${month}-${day}`
    }
  }
  
  // Handle YYYY-MM-DD (already ISO format)
  const isoMatch = input.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (isoMatch) {
    return input
  }
  
  return null
}

function isValidDate(year: string, month: string, day: string): boolean {
  const y = parseInt(year, 10)
  const m = parseInt(month, 10)
  const d = parseInt(day, 10)
  
  if (m < 1 || m > 12) return false
  if (d < 1 || d > 31) return false
  if (y < 1900 || y > 2100) return false
  
  // Check days in month
  const daysInMonth = new Date(y, m, 0).getDate()
  if (d > daysInMonth) return false
  
  return true
}

// Handle text input with auto-formatting
function handleInput(event: Event) {
  const target = event.target as HTMLInputElement
  let value = target.value
  
  // Auto-insert slashes as user types
  const digitsOnly = value.replace(/\D/g, '')
  
  if (digitsOnly.length >= 2 && digitsOnly.length <= 4) {
    // Format as MM/ or MM/DD
    const formatted = digitsOnly.slice(0, 2) + 
      (digitsOnly.length > 2 ? '/' + digitsOnly.slice(2) : '')
    displayValue.value = formatted
  } else if (digitsOnly.length > 4) {
    // Format as MM/DD/YYYY
    const formatted = digitsOnly.slice(0, 2) + '/' + 
      digitsOnly.slice(2, 4) + '/' + 
      digitsOnly.slice(4, 8)
    displayValue.value = formatted
  } else {
    displayValue.value = value
  }
}

// Handle blur to finalize and emit
function handleBlur() {
  const parsed = parseToISODate(displayValue.value)
  if (parsed) {
    emit('update:modelValue', parsed)
    displayValue.value = formatForDisplay(parsed)
  } else if (displayValue.value === '') {
    emit('update:modelValue', '')
  }
  // If invalid, revert to last known good value
  else {
    displayValue.value = formatForDisplay(props.modelValue)
  }
}

// Handle Enter key to apply
function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter') {
    handleBlur()
  }
}

// Click calendar icon to open native picker
function openPicker() {
  if (inputRef.value && !props.disabled) {
    inputRef.value.showPicker?.()
  }
}

// Handle native date picker change
function handleDateChange(event: Event) {
  const target = event.target as HTMLInputElement
  emit('update:modelValue', target.value)
  displayValue.value = formatForDisplay(target.value)
}

const containerClasses = computed(() => cn(
  'relative flex items-center',
  props.class
))

const textInputClasses = computed(() => cn(
  'flex h-10 w-full rounded-lg border border-input bg-background pl-10 pr-10 py-2 text-sm transition-all duration-150',
  'placeholder:text-muted-foreground/70',
  'hover:border-muted-foreground/30',
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:border-primary',
  'disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:border-input'
))
</script>

<template>
  <div :class="containerClasses">
    <!-- Clickable calendar icon with hidden date picker -->
    <div class="absolute left-0 z-20">
      <button
        type="button"
        :disabled="disabled"
        class="flex items-center justify-center w-10 h-10 rounded-l-lg hover:bg-white/10 transition-colors disabled:pointer-events-none"
        @click="openPicker"
        tabindex="-1"
      >
        <Calendar class="h-4 w-4 text-muted-foreground" />
      </button>
      <!-- Hidden native date picker - pointer-events-none so button can be clicked -->
      <input
        ref="inputRef"
        type="date"
        :value="modelValue"
        :disabled="disabled"
        class="absolute inset-0 opacity-0 pointer-events-none"
        tabindex="-1"
        @change="handleDateChange"
      />
    </div>
    
    <!-- Text input for typing dates -->
    <input
      type="text"
      :value="displayValue"
      :placeholder="placeholder || 'MM/DD/YYYY'"
      :disabled="disabled"
      :class="textInputClasses"
      @input="handleInput"
      @blur="handleBlur"
      @keydown="handleKeydown"
    />
  </div>
</template>
