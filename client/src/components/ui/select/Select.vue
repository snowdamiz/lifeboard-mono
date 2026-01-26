<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue'
import { ChevronDown, Check } from 'lucide-vue-next'
import { cn } from '@/lib/utils'

export interface SelectOption {
  value: string | number
  label: string
  disabled?: boolean
}

interface Props {
  modelValue?: string | number
  options: SelectOption[]
  placeholder?: string
  disabled?: boolean
  class?: string
  size?: 'default' | 'sm'
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: 'Select an option',
  disabled: false,
  size: 'default'
})

const emit = defineEmits<{
  'update:modelValue': [value: string | number]
}>()

const isOpen = ref(false)
const highlightedIndex = ref(-1)
const triggerRef = ref<HTMLButtonElement | null>(null)
const listboxRef = ref<HTMLDivElement | null>(null)

// Position state for teleported dropdown
const dropdownStyle = ref({
  top: '0px',
  left: '0px',
  width: '0px'
})

const selectedOption = computed(() => 
  props.options.find(opt => opt.value === props.modelValue)
)

const triggerClasses = computed(() => cn(
  'flex items-center justify-between w-full rounded-lg border border-input bg-background text-sm transition-all duration-150',
  'placeholder:text-muted-foreground/70',
  'hover:border-muted-foreground/30',
  'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:border-primary',
  'disabled:cursor-not-allowed disabled:opacity-50 disabled:hover:border-input',
  props.size === 'sm' ? 'h-9 px-3 py-1.5' : 'h-10 px-3.5 py-2',
  isOpen.value && 'ring-2 ring-ring/50 border-primary',
  props.class
))

const updateDropdownPosition = () => {
  if (!triggerRef.value) return
  
  const rect = triggerRef.value.getBoundingClientRect()
  const viewportHeight = window.innerHeight
  const spaceBelow = viewportHeight - rect.bottom
  const spaceAbove = rect.top
  const dropdownHeight = Math.min(props.options.length * 40 + 8, 248) // max-h-60 = 240px + padding
  
  // Determine if dropdown should appear above or below
  const showAbove = spaceBelow < dropdownHeight && spaceAbove > spaceBelow
  
  dropdownStyle.value = {
    top: showAbove 
      ? `${rect.top + window.scrollY - dropdownHeight - 6}px`
      : `${rect.bottom + window.scrollY + 6}px`,
    left: `${rect.left + window.scrollX}px`,
    width: `${rect.width}px`
  }
}

const toggle = () => {
  if (props.disabled) return
  isOpen.value = !isOpen.value
  if (isOpen.value) {
    highlightedIndex.value = props.options.findIndex(opt => opt.value === props.modelValue)
    nextTick(() => {
      updateDropdownPosition()
    })
  }
}

const close = () => {
  isOpen.value = false
  highlightedIndex.value = -1
}

const selectOption = (option: SelectOption) => {
  if (option.disabled) return
  emit('update:modelValue', option.value)
  close()
}

const handleKeydown = (e: KeyboardEvent) => {
  if (!isOpen.value) {
    if (e.key === 'Enter' || e.key === ' ' || e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault()
      isOpen.value = true
      highlightedIndex.value = props.options.findIndex(opt => opt.value === props.modelValue)
      if (highlightedIndex.value === -1) highlightedIndex.value = 0
      nextTick(() => {
        updateDropdownPosition()
      })
    }
    return
  }

  switch (e.key) {
    case 'ArrowDown':
      e.preventDefault()
      highlightedIndex.value = Math.min(highlightedIndex.value + 1, props.options.length - 1)
      break
    case 'ArrowUp':
      e.preventDefault()
      highlightedIndex.value = Math.max(highlightedIndex.value - 1, 0)
      break
    case 'Enter':
    case ' ':
      e.preventDefault()
      if (highlightedIndex.value >= 0) {
        selectOption(props.options[highlightedIndex.value])
      }
      break
    case 'Escape':
      e.preventDefault()
      close()
      triggerRef.value?.focus()
      break
    case 'Tab':
      close()
      break
  }
}

const handleClickOutside = (e: MouseEvent) => {
  if (!triggerRef.value?.contains(e.target as Node) && !listboxRef.value?.contains(e.target as Node)) {
    close()
  }
}

const handleScroll = () => {
  if (isOpen.value) {
    updateDropdownPosition()
  }
}

const handleResize = () => {
  if (isOpen.value) {
    updateDropdownPosition()
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
  window.addEventListener('scroll', handleScroll, true)
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
  window.removeEventListener('scroll', handleScroll, true)
  window.removeEventListener('resize', handleResize)
})

watch(highlightedIndex, (index) => {
  if (index >= 0 && listboxRef.value) {
    const container = listboxRef.value.querySelector('.overflow-auto')
    const item = container?.children[index] as HTMLElement
    item?.scrollIntoView({ block: 'nearest' })
  }
})
</script>

<template>
  <div class="relative">
    <button
      ref="triggerRef"
      type="button"
      role="combobox"
      :aria-expanded="isOpen"
      :aria-haspopup="true"
      :disabled="disabled"
      :class="triggerClasses"
      @click="toggle"
      @keydown="handleKeydown"
    >
      <span :class="['truncate', !selectedOption && 'text-muted-foreground/70']">
        {{ selectedOption?.label || placeholder }}
      </span>
      <ChevronDown 
        :class="[
          'h-4 w-4 shrink-0 text-muted-foreground/70 transition-transform duration-200',
          isOpen && 'rotate-180'
        ]" 
      />
    </button>

    <Teleport to="body">
      <Transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="opacity-0 scale-95"
        enter-to-class="opacity-100 scale-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="opacity-100 scale-100"
        leave-to-class="opacity-0 scale-95"
      >
        <div
          v-if="isOpen"
          ref="listboxRef"
          role="listbox"
          class="fixed z-[9999] overflow-hidden rounded-lg border border-border bg-popover text-popover-foreground shadow-xl shadow-black/10 pointer-events-auto"
          :style="{
            top: dropdownStyle.top,
            left: dropdownStyle.left,
            width: dropdownStyle.width,
            minWidth: '8rem'
          }"
          @pointerdown.stop
        >
          <div class="max-h-60 overflow-auto p-1">
            <div
              v-for="(option, index) in options"
              :key="option.value"
              role="option"
              :aria-selected="option.value === modelValue"
              :class="[
                'relative flex cursor-pointer select-none items-center rounded-md px-3 py-2 text-sm outline-none transition-colors',
                option.value === modelValue && 'font-medium',
                option.disabled && 'pointer-events-none opacity-50',
                highlightedIndex === index && 'bg-secondary',
                option.value === modelValue && highlightedIndex !== index && 'bg-primary/5'
              ]"
              @click.stop.prevent="selectOption(option)"
              @mouseenter="highlightedIndex = index"
            >
              <span class="flex-1 truncate">{{ option.label }}</span>
              <Check 
                v-if="option.value === modelValue"
                class="h-4 w-4 shrink-0 text-primary ml-2" 
              />
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>
