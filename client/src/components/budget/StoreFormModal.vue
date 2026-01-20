<script setup lang="ts">
import { ref, watch, onMounted } from 'vue'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import type { Store } from '@/types'
import { useReceiptsStore } from '@/stores/receipts'

const props = defineProps<{
  open: boolean
  store: Store | null
}>()

const emit = defineEmits<{
  (e: 'update:open', value: boolean): void
  (e: 'saved', store: Store): void
}>()

const receiptsStore = useReceiptsStore()
const loading = ref(false)
const error = ref('')

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
  } else {
    form.value = {
      name: '',
      address: '',
      state: '',
      store_code: '',
      tax_rate: ''
    }
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
    <DialogContent class="sm:max-w-[425px]">
      <DialogHeader>
        <DialogTitle>{{ store ? 'Edit Store' : 'Add Store' }}</DialogTitle>
        <DialogDescription>
          {{ store ? 'Update store details and location.' : 'Add a new store location to track purchases.' }}
        </DialogDescription>
      </DialogHeader>

      <div class="grid gap-4 py-4">
        <div class="grid grid-cols-4 items-center gap-4">
          <label for="name" class="text-right text-sm font-medium">Name</label>
          <Input id="name" v-model="form.name" class="col-span-3" placeholder="e.g. Walmart" />
        </div>
        
        <div class="grid grid-cols-4 items-center gap-4">
          <label for="address" class="text-right text-sm font-medium">Address</label>
          <Input id="address" v-model="form.address" class="col-span-3" placeholder="Street address" />
        </div>

        <div class="grid grid-cols-4 items-center gap-4">
          <label for="state" class="text-right text-sm font-medium">State</label>
          <Input id="state" v-model="form.state" class="col-span-3" placeholder="e.g. CA" maxlength="2" />
        </div>

        <div class="grid grid-cols-4 items-center gap-4">
          <label for="tax_rate" class="text-right text-sm font-medium">Tax Rate %</label>
          <Input id="tax_rate" v-model="form.tax_rate" type="number" step="0.01" class="col-span-3" placeholder="e.g. 8.25" />
        </div>

        <div class="grid grid-cols-4 items-center gap-4">
          <label for="store_code" class="text-right text-sm font-medium">Code</label>
          <Input id="store_code" v-model="form.store_code" class="col-span-3" placeholder="Optional internal code" />
        </div>

        <div v-if="error" class="col-span-4 text-center text-sm text-destructive">
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
