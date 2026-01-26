<script setup lang="ts">
import { ref, watch, onMounted, computed } from 'vue'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import type { Store } from '@/types'
import { useReceiptsStore } from '@/stores/receipts'

const props = defineProps<{
  open: boolean
  store: Store | null
  initialName?: string
}>()

const emit = defineEmits<{
  (e: 'update:open', value: boolean): void
  (e: 'saved', store: Store): void
}>()

const receiptsStore = useReceiptsStore()
const loading = ref(false)
const error = ref('')

// For SearchableInput
const nameSearchText = ref('')
const addressSearchText = ref('')
const stateSearchText = ref('')
const taxRateSearchText = ref('')
const codeSearchText = ref('')
const stores = computed(() => receiptsStore.stores)

// Unique values for autocomplete
const uniqueAddresses = computed(() => {
  const addresses = stores.value.map(s => s.address).filter(a => a && a.trim())
  return [...new Set(addresses)]
})

const uniqueStates = computed(() => {
  const states = stores.value.map(s => s.state).filter(s => s && s.trim())
  return [...new Set(states)]
})

const uniqueTaxRates = computed(() => {
  const rates = stores.value.map(s => {
    if (s.tax_rate) {
      return parseFloat((parseFloat(s.tax_rate) * 100).toFixed(4)).toString()
    }
    return null
  }).filter(r => r)
  return [...new Set(rates)]
})

const uniqueCodes = computed(() => {
  const codes = stores.value.map(s => s.store_code).filter(c => c && c.trim())
  return [...new Set(codes)]
})

const form = ref({
  name: '',
  address: '',
  state: '',
  store_code: '',
  tax_rate: ''
})

watch(() => props.store, (newStore) => {
  if (newStore) {
    form.value = {
      name: newStore.name,
      address: newStore.address || '',
      state: newStore.state || '',
      store_code: newStore.store_code || '',
      tax_rate: newStore.tax_rate ? parseFloat((parseFloat(newStore.tax_rate) * 100).toFixed(4)).toString() : ''
    }
    nameSearchText.value = newStore.name
    addressSearchText.value = newStore.address || ''
    stateSearchText.value = newStore.state || ''
    taxRateSearchText.value = newStore.tax_rate ? parseFloat((parseFloat(newStore.tax_rate) * 100).toFixed(4)).toString() : ''
    codeSearchText.value = newStore.store_code || ''
  } else {
    form.value = {
      name: props.initialName || '',
      address: '',
      state: '',
      store_code: '',
      tax_rate: ''
    }
    nameSearchText.value = props.initialName || ''
    addressSearchText.value = ''
    stateSearchText.value = ''
    taxRateSearchText.value = ''
    codeSearchText.value = ''
  }
}, { immediate: true })

watch(() => form.value.state, (newState) => {
  if (!newState) return
  
  const state = newState.toUpperCase()
  if (state === 'MI') {
    form.value.tax_rate = '6'
  } else if (state === 'IN') {
    form.value.tax_rate = '7'
  }
})

const searchStores = async (query: string) => {
  const q = query.toLowerCase()
  return stores.value.filter(s => s.name.toLowerCase().includes(q))
}

const selectStore = (store: Store) => {
  nameSearchText.value = store.name
  form.value.name = store.name
  form.value.address = store.address || ''
  form.value.state = store.state || ''
  form.value.store_code = store.store_code || ''
  form.value.tax_rate = store.tax_rate ? parseFloat((parseFloat(store.tax_rate) * 100).toFixed(4)).toString() : ''
}

const handleCreateStore = (name: string) => {
  nameSearchText.value = name
  form.value.name = name
}

const searchAddresses = async (query: string) => {
  const q = query.toLowerCase()
  return uniqueAddresses.value.filter(a => a && a.toLowerCase().includes(q))
}

const selectAddress = (address: string) => {
  addressSearchText.value = address
  form.value.address = address
}

const handleCreateAddress = (address: string) => {
  addressSearchText.value = address
  form.value.address = address
}

const searchStates = async (query: string) => {
  const q = query.toLowerCase()
  return uniqueStates.value.filter(s => s && s.toLowerCase().includes(q))
}

const selectState = (state: string) => {
  stateSearchText.value = state
  form.value.state = state
}

const handleCreateState = (state: string) => {
  stateSearchText.value = state
  form.value.state = state
}

const searchTaxRates = async (query: string) => {
  const q = query.toLowerCase()
  return uniqueTaxRates.value.filter(r => r && r.toLowerCase().includes(q))
}

const selectTaxRate = (rate: string) => {
  taxRateSearchText.value = rate
  form.value.tax_rate = rate
}

const handleCreateTaxRate = (rate: string) => {
  taxRateSearchText.value = rate
  form.value.tax_rate = rate
}

const searchCodes = async (query: string) => {
  const q = query.toLowerCase()
  return uniqueCodes.value.filter(c => c && c.toLowerCase().includes(q))
}

const selectCode = (code: string) => {
  codeSearchText.value = code
  form.value.store_code = code
}

const handleCreateCode = (code: string) => {
  codeSearchText.value = code
  form.value.store_code = code
}

onMounted(async () => {
  await receiptsStore.fetchStores()
})

const handleSubmit = async () => {
  if (!form.value.name) {
    error.value = 'Name is required'
    return
  }

  loading.value = true
  error.value = ''

  try {
    const storeData = {
      name: form.value.name,
      address: form.value.address || null,
      state: form.value.state || null,
      store_code: form.value.store_code || null,
      tax_rate: form.value.tax_rate ? (parseFloat(form.value.tax_rate) / 100).toString() : null
    }

    let savedStore
    if (props.store) {
      savedStore = await receiptsStore.updateStore(props.store.id, storeData)
    } else {
      savedStore = await receiptsStore.createStore(storeData)
    }
    
    emit('saved', savedStore)
    emit('update:open', false)
  } catch (e: any) {
    error.value = e.message || 'Failed to save store'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <Dialog :open="open" @update:open="$emit('update:open', $event)">
    <DialogContent class="sm:max-w-[500px]">
      <DialogHeader>
        <DialogTitle>{{ store ? 'Edit Store' : 'Add Store' }}</DialogTitle>
        <DialogDescription>
          {{ store ? 'Update store details and location.' : 'Add a new store location to track purchases.' }}
        </DialogDescription>
      </DialogHeader>

      <div class="space-y-4 py-4">
        <div>
          <label class="text-sm font-medium">Name</label>
          <SearchableInput 
            v-model="nameSearchText"
            @update:model-value="form.name = $event"
            @select="selectStore"
            @create="handleCreateStore"
            :search-function="searchStores"
            :display-function="(s) => s.name"
            :value-function="(s) => s.name"
            :show-create-option="true"
            :min-chars="0"
            placeholder="Search or create store" 
            class="mt-1.5"
          />
        </div>
        
        <div>
          <label class="text-sm font-medium">Address</label>
          <SearchableInput 
            v-model="addressSearchText"
            @update:model-value="form.address = $event"
            @select="selectAddress"
            @create="handleCreateAddress"
            :search-function="searchAddresses"
            :show-create-option="true"
            :min-chars="0"
            placeholder="Street address" 
            class="mt-1.5"
          />
        </div>

        <div>
          <label class="text-sm font-medium">State</label>
          <SearchableInput 
            v-model="stateSearchText"
            @update:model-value="form.state = $event"
            @select="selectState"
            @create="handleCreateState"
            :search-function="searchStates"
            :show-create-option="true"
            :min-chars="0"
            placeholder="e.g. CA" 
            class="mt-1.5"
          />
        </div>

        <div>
          <label class="text-sm font-medium">Tax Rate %</label>
          <SearchableInput 
            v-model="taxRateSearchText"
            @update:model-value="form.tax_rate = $event"
            @select="selectTaxRate"
            @create="handleCreateTaxRate"
            :search-function="searchTaxRates"
            :show-create-option="true"
            :min-chars="0"
            placeholder="e.g. 8.25" 
            class="mt-1.5"
          />
        </div>

        <div>
          <label class="text-sm font-medium">Code</label>
          <SearchableInput 
            v-model="codeSearchText"
            @update:model-value="form.store_code = $event"
            @select="selectCode"
            @create="handleCreateCode"
            :search-function="searchCodes"
            :show-create-option="true"
            :min-chars="0"
            placeholder="Optional internal code" 
            class="mt-1.5"
          />
        </div>

        <div v-if="error" class="text-center text-sm text-destructive">
          {{ error }}
        </div>
      </div>

      <DialogFooter>
        <Button variant="outline" @click="$emit('update:open', false)">Cancel</Button>
        <Button @click="handleSubmit" :disabled="loading">
          {{ loading ? 'Saving...' : 'Save Store' }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
