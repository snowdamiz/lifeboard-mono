<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { format } from 'date-fns'
import { X, Plus } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select, type SelectOption } from '@/components/ui/select'
import { useBudgetStore } from '@/stores/budget'

interface Props {
  initialDate?: Date | null
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  saved: []
}>()

const budgetStore = useBudgetStore()
const saving = ref(false)
const showNewSource = ref(false)
const newSourceName = ref('')
const newSourceAmount = ref('')
const creatingSource = ref(false)

const form = ref({
  date: props.initialDate ? format(props.initialDate, 'yyyy-MM-dd') : format(new Date(), 'yyyy-MM-dd'),
  type: 'expense' as 'income' | 'expense',
  amount: '',
  source_id: '',
  notes: ''
})

const filteredSources = computed(() => 
  budgetStore.sources.filter(s => s.type === form.value.type)
)

const sourceOptions = computed<SelectOption[]>(() => [
  { value: '', label: 'No source' },
  ...filteredSources.value.map(s => ({ value: s.id, label: s.name }))
])

onMounted(() => {
  if (budgetStore.sources.length === 0) {
    budgetStore.fetchSources()
  }
})

const selectSource = (sourceId: string) => {
  form.value.source_id = sourceId
  const source = budgetStore.sources.find(s => s.id === sourceId)
  if (source) {
    form.value.amount = source.amount
    form.value.type = source.type
  }
}

const createNewSource = async () => {
  if (!newSourceName.value.trim()) return
  
  creatingSource.value = true
  try {
    const source = await budgetStore.createSource({
      name: newSourceName.value,
      type: form.value.type,
      amount: newSourceAmount.value || '0',
      is_recurring: false,
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
  
  saving.value = true
  
  try {
    await budgetStore.createEntry({
      date: form.value.date,
      type: form.value.type,
      amount: form.value.amount,
      source_id: form.value.source_id || null,
      notes: form.value.notes || null
    })
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
          <h2 class="text-lg font-semibold">Add Entry</h2>
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
            <div class="flex gap-2 mt-1">
              <Select
                v-model="form.source_id"
                :options="sourceOptions"
                placeholder="No source"
                size="sm"
                class="flex-1"
                @update:model-value="selectSource(form.source_id)"
              />
              <Button 
                type="button" 
                variant="outline" 
                size="icon" 
                class="shrink-0"
                @click="showNewSource = !showNewSource"
                :title="showNewSource ? 'Cancel' : 'Add new source'"
              >
                <Plus :class="['h-4 w-4 transition-transform', showNewSource && 'rotate-45']" />
              </Button>
            </div>
            
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
            {{ saving ? 'Saving...' : 'Add Entry' }}
          </Button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

