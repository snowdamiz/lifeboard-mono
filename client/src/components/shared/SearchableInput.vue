<script setup lang="ts">
import { ref, watch } from 'vue'
import { Input } from '@/components/ui/input'
import { Plus, X } from 'lucide-vue-next'
import { onClickOutside } from '@vueuse/core'
import { debounce } from '@/lib/utils'

interface Props {
  modelValue: string
  placeholder?: string
  searchFunction: (query: string) => Promise<any[]>
  minChars?: number
  disabled?: boolean
  displayFunction?: (item: any) => string
  valueFunction?: (item: any) => string
  showCreateOption?: boolean
  inputClass?: string
  onDelete?: (value: string) => Promise<boolean>
}

const props = withDefaults(defineProps<Props>(), {
  modelValue: '',
  placeholder: '',
  minChars: 1,
  disabled: false,
  displayFunction: (item: any) => String(item),
  valueFunction: (item: any) => String(item),
  showCreateOption: false,
  inputClass: ''
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
  'select': [value: any]
  'create': [query: string]
}>()

const suggestions = ref<any[]>([])
const showDropdown = ref(false)
const lastQuery = ref('')
const loading = ref(false)
const inputFocused = ref(false)
const containerRef = ref<HTMLElement | null>(null)

onClickOutside(containerRef, () => {
    showDropdown.value = false
    inputFocused.value = false
})

const handleInput = (e: Event) => {
  const target = e.target as HTMLInputElement
  emit('update:modelValue', target.value)
}

const selectItem = (item: any) => {
  const value = props.valueFunction(item)
  emit('update:modelValue', value)
  emit('select', item)
  showDropdown.value = false
  inputFocused.value = false
}

const handleCreate = () => {
    emit('create', props.modelValue)
    showDropdown.value = false
    inputFocused.value = false
}

const handleDelete = async (item: any, event: Event) => {
  event.stopPropagation()
  if (!props.onDelete) return
  
  const value = props.valueFunction(item)
  const success = await props.onDelete(value)
  
  if (success) {
    // Remove from suggestions list
    suggestions.value = suggestions.value.filter(s => props.valueFunction(s) !== value)
    // If no more suggestions, hide dropdown
    if (suggestions.value.length === 0 && !props.showCreateOption) {
      showDropdown.value = false
    }
  }
}

  // Debounced search function to prevent excessive API calls
  const debouncedSearch = debounce(async (query: string) => {
    await performSearch(query)
  }, 300)

  // Watch model value to trigger search
  watch(() => props.modelValue, (newValue) => {
    // console.log('DEBUG: modelValue changed', { newValue, inputFocused: inputFocused.value })
    if (!inputFocused.value) return // Don't search if not typing (e.g. programmatic update or initial load)
    debouncedSearch(newValue)
  })

  const performSearch = async (query: string) => {
    // console.log('DEBUG: performSearch', { query, lastQuery: lastQuery.value, minChars: props.minChars })
    const trimmedQuery = query.trim()
    
    if (trimmedQuery.length < props.minChars) {
      // console.log('DEBUG: query too short, clearing')
      suggestions.value = []
      showDropdown.value = false
      return
    }
  
    // Avoid duplicate searches if multiple events fire
    if (trimmedQuery === lastQuery.value && suggestions.value.length > 0) {
       // console.log('DEBUG: reusing results')
       showDropdown.value = true
       return
    }
  
    loading.value = true
    lastQuery.value = trimmedQuery
    try {
      // console.log('DEBUG: calling searchFunction', trimmedQuery)
      const results = await props.searchFunction(trimmedQuery)
      // console.log('DEBUG: results received', results.length)
      
      if (lastQuery.value === trimmedQuery) {
          suggestions.value = results
          showDropdown.value = results.length > 0 || (props.showCreateOption && trimmedQuery.length > 0)
          // console.log('DEBUG: suggestions updated', { count: suggestions.value.length, showDropdown: showDropdown.value })
      } else {
        // console.log('DEBUG: query changed during search, ignoring results')
      }
    } catch (e) {
      console.error('Search error:', e)
      suggestions.value = []
    } finally {
      loading.value = false
    }
  }


const onFocus = () => {
    inputFocused.value = true
    // Allow search if minChars is 0, even if modelValue is empty
    if ((props.modelValue && props.modelValue.length >= props.minChars) || props.minChars === 0) {
        if (suggestions.value.length > 0 || (props.showCreateOption && props.modelValue)) {
            showDropdown.value = true
        } else {
           performSearch(props.modelValue || '')
        }
    }
}

const handleEnter = (e: KeyboardEvent) => {
    if (showDropdown.value && suggestions.value.length > 0) {
        e.preventDefault()
        // Find exact match first
        const exact = suggestions.value.find(s => props.valueFunction(s).toLowerCase() === props.modelValue.toLowerCase())
        if (exact) {
            selectItem(exact)
        } else {
            // Select first
            selectItem(suggestions.value[0])
        }
    } else if (props.showCreateOption && props.modelValue.trim()) {
        e.preventDefault()
        handleCreate()
    }
}
</script>

<template>
  <div class="relative" ref="containerRef">
    <Input 
      :model-value="modelValue"
      @input="handleInput"
      @focus="onFocus"
      @keydown.enter="handleEnter"
      :placeholder="placeholder"
      :disabled="disabled"
      class="w-full"
      :class="inputClass"
      autocomplete="off"
    />
    
    <div 
      v-if="showDropdown" 
      class="absolute top-full left-0 right-0 mt-1 bg-popover border border-border rounded-lg shadow-lg z-50 max-h-60 overflow-auto animate-in fade-in zoom-in-95 duration-100"
    >
        <template v-if="suggestions.length > 0">
            <div
                v-for="(item, index) in suggestions"
                :key="index"
                class="flex items-center justify-between hover:bg-accent border-b border-border last:border-0 transition-colors group"
            >
                <button
                    type="button"
                    class="flex-1 text-left px-3 py-2 text-sm font-medium"
                    @click="selectItem(item)"
                >
                    {{ displayFunction(item) }}
                </button>
                <button
                    v-if="onDelete"
                    type="button"
                    class="px-2 py-2 opacity-0 group-hover:opacity-100 hover:text-destructive transition-opacity"
                    @click="handleDelete(item, $event)"
                    title="Delete this suggestion"
                >
                    <X class="h-3.5 w-3.5" />
                </button>
            </div>
        </template>
        
        <button
            v-if="showCreateOption && modelValue.trim().length > 0"
            type="button"
            class="w-full text-left px-3 py-2 hover:bg-accent text-sm text-primary font-medium flex items-center gap-2 border-t border-border"
            @click="handleCreate"
        >
            <Plus class="h-3 w-3" />
            Create "{{ modelValue }}"
        </button>
    </div>
  </div>
</template>
