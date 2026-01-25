<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { format } from 'date-fns'
import { X, Plus, PlusCircle, MinusCircle } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select, type SelectOption } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { useBudgetStore } from '@/stores/budget'
import { useTagsStore } from '@/stores/tags'
import TagManager from '@/components/shared/TagManager.vue'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import { useTextTemplate } from '@/composables/useTextTemplate'
import type { BudgetEntry } from '@/types'

// Templates
const budgetDescriptionTemplate = useTextTemplate('budget_description')

interface Props {
  initialDate?: Date | null
  entry?: BudgetEntry | null
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  saved: []
}>()

const budgetStore = useBudgetStore()
const tagsStore = useTagsStore()
const saving = ref(false)
const showNewSource = ref(false)
const newSourceName = ref('')
const newSourceAmount = ref('')
const creatingSource = ref(false)

const isEditing = computed(() => !!props.entry)

const form = ref({
  date: props.entry?.date || (props.initialDate ? format(props.initialDate, 'yyyy-MM-dd') : format(new Date(), 'yyyy-MM-dd')),
  type: (props.entry?.type || 'expense') as 'income' | 'expense',
  amount: props.entry?.amount || '',
  source_id: props.entry?.source_id || '',
  notes: props.entry?.notes || '',
  tag_ids: props.entry?.tags?.map(t => t.id) || [] as string[]
})

// Tag Management
const checkedTagIds = ref<Set<string>>(new Set())
const tagManagerRef = ref<InstanceType<typeof TagManager> | null>(null)

const addCheckedTags = () => {
  if (!tagManagerRef.value) return
  checkedTagIds.value.forEach(tagId => {
    if (!form.value.tag_ids.includes(tagId)) {
      form.value.tag_ids.push(tagId)
    }
  })
  checkedTagIds.value = new Set()
}

const removeCheckedTags = () => {
  form.value.tag_ids = form.value.tag_ids.filter(
    id => !checkedTagIds.value.has(id)
  )
  checkedTagIds.value = new Set()
}

// Helper to get tag by ID
const getTagById = (tagId: string) => {
  return tagsStore.tags.find(t => t.id === tagId)
}

// Helper to get tag style for badges
const getTagStyle = (tagId: string) => {
  const tag = getTagById(tagId)
  if (!tag) return {}
  return { 
    backgroundColor: tag.color + '20', 
    color: tag.color, 
    borderColor: tag.color + '40' 
  }
}

// Helper to get tag color
const getTagColor = (tagId: string) => {
  const tag = getTagById(tagId)
  return tag?.color || '#64748b'
}

// Helper to get tag name
const getTagName = (tagId: string) => {
  const tag = getTagById(tagId)
  return tag?.name || 'Unknown'
}

const filteredSources = computed(() => 
  budgetStore.sources.filter(s => s.type === form.value.type || (form.value.source_id && s.id === form.value.source_id))
)

const searchSources = async (query: string) => {
    const q = query.toLowerCase()
    return filteredSources.value.filter(s => s.name.toLowerCase().includes(q))
}

const sourceOptions = computed<SelectOption[]>(() => [
  { value: '', label: 'No source' },
  ...filteredSources.value.map(s => ({ value: s.id, label: s.name }))
])

onMounted(async () => {
  await Promise.all([
    budgetStore.sources.length === 0 ? budgetStore.fetchSources() : Promise.resolve(),
    tagsStore.tags.length === 0 ? tagsStore.fetchTags() : Promise.resolve()
  ])
})

const selectSource = (sourceId: string) => {
  form.value.source_id = sourceId
  const source = budgetStore.sources.find(s => s.id === sourceId)
  if (source) {
    form.value.amount = source.amount
    form.value.type = source.type
  }
}

const handleCreateSourceWithName = (name: string) => {
    newSourceName.value = name
    showNewSource.value = true
}

const createNewSource = async () => {
  if (!newSourceName.value.trim()) return
  
  creatingSource.value = true
  try {
    const source = await budgetStore.createSource({
      name: newSourceName.value,
      type: form.value.type,
      amount: newSourceAmount.value || '0',
      tags: []
    })
    // Select the newly created source
    form.value.source_id = source.id
    if (newSourceAmount.value) {
      form.value.amount = newSourceAmount.value
    }
    // Reset and close
    newSourceName.value = ''
    newSourceAmount.value = ''
    showNewSource.value = false
  } finally {
    creatingSource.value = false
  }
}

const save = async () => {
  if (!form.value.amount) return
  
  // Save template
  if (form.value.notes) {
    budgetDescriptionTemplate.save(form.value.notes)
  }

  saving.value = true
  
  try {
    if (isEditing.value && props.entry) {
      await budgetStore.updateEntry(props.entry.id, {
        date: form.value.date,
        type: form.value.type,
        amount: form.value.amount,
        source_id: form.value.source_id || null,
        notes: form.value.notes || null,
        tag_ids: form.value.tag_ids
      })
    } else {
      await budgetStore.createEntry({
        date: form.value.date,
        type: form.value.type,
        amount: form.value.amount,
        source_id: form.value.source_id || null,
        notes: form.value.notes || null,
        tag_ids: form.value.tag_ids
      })
    }
    emit('saved')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="w-full sm:max-w-md bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[90vh] sm:max-h-[85vh] flex flex-col">
        <div class="flex items-center justify-between p-4 border-b border-border shrink-0">
          <h2 class="text-lg font-semibold">{{ isEditing ? 'Edit Entry' : 'Add Entry' }}</h2>
          <Button variant="ghost" size="icon" @click="emit('close')">
            <X class="h-4 w-4" />
          </Button>
        </div>

        <form class="flex-1 overflow-auto p-4 space-y-4" @submit.prevent="save">
          <div>
            <label class="text-sm font-medium">Date</label>
            <Input v-model="form.date" type="date" class="mt-1" />
          </div>

          <div>
            <label class="text-sm font-medium">Type</label>
            <div class="grid grid-cols-2 gap-2 mt-1">
              <button
                type="button"
                :class="[
                  'p-2 rounded-lg border text-sm font-medium transition-colors',
                  form.type === 'income' 
                    ? 'border-green-500 bg-green-500/10 text-green-500' 
                    : 'border-border hover:border-green-500/50'
                ]"
                @click="form.type = 'income'"
              >
                Income
              </button>
              <button
                type="button"
                :class="[
                  'p-2 rounded-lg border text-sm font-medium transition-colors',
                  form.type === 'expense' 
                    ? 'border-red-500 bg-red-500/10 text-red-500' 
                    : 'border-border hover:border-red-500/50'
                ]"
                @click="form.type = 'expense'"
              >
                Expense
              </button>
            </div>
          </div>

          <div>
            <label class="text-sm font-medium">Source (optional)</label>
              <SearchableInput 
                :model-value="(() => {
                    const s = budgetStore.sources.find(s => s.id === form.source_id)
                    return s ? s.name : ''
                })()"
                @update:model-value="(val) => {
                     if (!val) form.source_id = ''
                }"
                @select="(source) => selectSource(source.id)"
                :search-function="searchSources"
                :display-function="(s) => s.name"
                :value-function="(s) => s.name"
                :show-create-option="true"
                :min-chars="0"
                placeholder="Select or create source"
                size="sm"
                class="flex-1"
                @create="handleCreateSourceWithName"
              />
            
            <!-- Quick add source form -->
            <div v-if="showNewSource" class="mt-3 p-3 rounded-lg border border-border bg-muted/30 space-y-3">
              <p class="text-xs font-medium text-muted-foreground">
                Add new {{ form.type }} source
              </p>
              <Input 
                v-model="newSourceName" 
                placeholder="Source name" 
                class="h-8 text-sm"
              />
              <Input 
                v-model="newSourceAmount" 
                type="number" 
                step="0.01" 
                min="0" 
                placeholder="Default amount (optional)" 
                class="h-8 text-sm"
              />
              <div class="flex justify-end gap-2">
                <Button 
                  type="button" 
                  variant="ghost" 
                  size="sm"
                  @click="showNewSource = false; newSourceName = ''; newSourceAmount = ''"
                >
                  Cancel
                </Button>
                <Button 
                  type="button" 
                  size="sm"
                  :disabled="!newSourceName.trim() || creatingSource"
                  @click="createNewSource"
                >
                  {{ creatingSource ? 'Adding...' : 'Add Source' }}
                </Button>
              </div>
            </div>
          </div>

          <div>
            <label class="text-sm font-medium">Amount</label>
            <Input v-model="form.amount" type="number" step="0.01" min="0" placeholder="0.00" class="mt-1" />
          </div>

          <div>
            <label class="text-sm font-medium">Tags</label>
            <div class="flex flex-wrap gap-1.5 mb-2" v-if="form.tag_ids.length > 0">
              <Badge
                v-for="tagId in form.tag_ids"
                :key="tagId"
                :style="getTagStyle(tagId)"
                variant="outline"
                class="gap-1 pr-1"
              >
                <div 
                  class="h-1.5 w-1.5 rounded-full" 
                  :style="{ backgroundColor: getTagColor(tagId) }"
                />
                {{ getTagName(tagId) }}
                <button
                  type="button"
                  class="ml-0.5 rounded-full hover:bg-black/10 p-0.5"
                  @click="form.tag_ids = form.tag_ids.filter(id => id !== tagId)"
                >
                  <X class="h-3 w-3" />
                </button>
              </Badge>
            </div>
            <TagManager
                ref="tagManagerRef"
                v-model:checkedTagIds="checkedTagIds"
                :compact="true"
                embedded
                :rows="2"
                :applied-tag-ids="new Set(form.tag_ids)"
            >
              <template #actions="{ checkedCount }">
                <div class="flex items-center gap-2 px-4 py-2 border-t border-border">
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    class="h-7 px-2 text-xs"
                    :disabled="checkedCount === 0"
                    @click="addCheckedTags"
                  >
                    <PlusCircle class="h-3 w-3 mr-1" />
                    Add
                  </Button>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    class="h-7 px-2 text-xs"
                    :disabled="checkedCount === 0"
                    @click="removeCheckedTags"
                  >
                    <MinusCircle class="h-3 w-3 mr-1" />
                    Remove
                  </Button>
                </div>
              </template>
            </TagManager>
          </div>

          <div>
            <label class="text-sm font-medium">Notes (optional)</label>
            <textarea
              v-model="form.notes"
              placeholder="Optional notes..."
              class="mt-1 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring min-h-[60px]"
            />
          </div>

        </form>
        
        <!-- Fixed Footer -->
        <div class="flex gap-3 p-4 border-t border-border bg-card shrink-0">
          <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="emit('close')">
            Cancel
          </Button>
          <Button type="submit" class="flex-1 sm:flex-none sm:ml-auto" :disabled="saving || !form.amount" @click="save">
            {{ saving ? 'Saving...' : (isEditing ? 'Update Entry' : 'Add Entry') }}
          </Button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
