<script setup lang="ts">
import { ref, watch, computed, onMounted } from 'vue'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Checkbox } from '@/components/ui/checkbox'
import { Plus, X } from 'lucide-vue-next'
import type { Store, Brand, Unit, Purchase } from '@/types'
import { useReceiptsStore } from '@/stores/receipts'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import { COUNT_UNIT_OPTIONS, mergeUnitsWithDefaults } from '@/utils/units'

interface InventoryItem {
  id: string
  source: string
  brand: string | null
  name: string
  unit: string | null
  price: string | null
  date: string
  store_code?: string | null
  item_name?: string | null
}

const props = defineProps<{
  open: boolean
  store: Store | null
  item: InventoryItem | null
}>()

const emit = defineEmits<{
  (e: 'update:open', value: boolean): void
  (e: 'saved'): void
}>()

const receiptsStore = useReceiptsStore()
const loading = ref(false)
const error = ref('')

const form = ref({
  brand: '',
  name: '',
  unit: '',
  price: '',
  store_code: '',
  item_name: '',
  quantity: '',
  quantity_unit: '',
  count: '',
  count_unit: '',
  usage_mode: 'count'
})

// Search States
const brandSearch = ref('')
const itemSearch = ref('')
const unitSearch = ref('')

// Bulk update state
const propagate = ref(true)

// Initialize form and search states
watch(() => props.item, (newItem) => {
  if (newItem) {
    form.value = {
      brand: newItem.brand || '',
      name: newItem.name,
      unit: newItem.unit || '',
      price: newItem.price || '',
      store_code: newItem.store_code || '',
      item_name: newItem.item_name || '',
      quantity: (newItem as any).quantity || '',
      quantity_unit: (newItem as any).quantity_unit || '',
      count: (newItem as any).count || '',
      count_unit: (newItem as any).count_unit || '',
      usage_mode: (newItem as any).usage_mode || 'count'
    }
    brandSearch.value = newItem.brand || ''
    itemSearch.value = newItem.name
    unitSearch.value = newItem.unit || ''
  } else {
    form.value = {
      brand: '',
      name: '',
      unit: '',
      price: '',
      store_code: '',
      item_name: '',
      quantity: '',
      quantity_unit: '',
      count: '',
      count_unit: '',
      usage_mode: 'count'
    }
    brandSearch.value = ''
    itemSearch.value = ''
    unitSearch.value = ''
  }
  propagate.value = true
}, { immediate: true })

// Sync search inputs with form
watch(brandSearch, (val) => {
  form.value.brand = val
})
watch(itemSearch, (val) => {
  form.value.name = val
})
watch(unitSearch, (val) => {
  form.value.unit = val
})

// Brand Search Logic
const searchBrands = async (query: string) => {
    if (!query) return receiptsStore.brands
    if (receiptsStore.brands.length > 0) {
        const q = query.toLowerCase()
        return receiptsStore.brands.filter(b => b.name.toLowerCase().includes(q))
    }
    // Fallback if not loaded (though we load on mount)
    try {
        return await receiptsStore.searchBrands(query)
    } catch {
        return []
    }
}

const selectBrand = async (brand: Brand) => {
    brandSearch.value = brand.name
    form.value.brand = brand.name // Ensure form is updated
    
    // Auto-population (Store is fixed as props.store)
    if (props.store) {
        try {
            const suggestion = await receiptsStore.getSuggestionsByBrand(brand.name, props.store.id)
            if (suggestion.recent_purchases && suggestion.recent_purchases.length > 0) {
              const latest = suggestion.recent_purchases[0]
              
              if (!form.value.name) {
                  form.value.name = latest.item
                  itemSearch.value = latest.item
              } 
              if (!form.value.unit && latest.unit_measurement) {
                  form.value.unit = latest.unit_measurement
                  unitSearch.value = latest.unit_measurement
              }
              if (!form.value.count_unit && latest.count_unit) {
                  form.value.count_unit = latest.count_unit
              }
              if (!form.value.store_code && latest.store_code) form.value.store_code = latest.store_code
              if (!form.value.item_name && latest.item_name) form.value.item_name = latest.item_name
          }
        } catch (e) {
            console.error("Failed to get suggestions", e)
        }
    }

    // Apply brand defaults
    if (brand.default_count_unit && !form.value.count_unit) {
        form.value.count_unit = brand.default_count_unit
    }
}

// Item Search Logic
const searchItems = async (query: string) => {
    if (!query || query.length < 2) return []
    try {
        const results = await receiptsStore.getSuggestionsByItem(query)
        const flat: Purchase[] = []
        results.forEach(res => {
            if (res.recent_purchases) {
                flat.push(...res.recent_purchases)
            }
        })
        const unique = new Map<string, Purchase>()
        flat.forEach(p => {
             const key = `${p.item}-${p.brand}`
             if (!unique.has(key)) {
                 unique.set(key, p)
             }
        })
        return Array.from(unique.values()).slice(0, 10)
    } catch {
        return []
    }
}

const selectItem = (purchase: Purchase) => {
    itemSearch.value = purchase.item
    // Optional: Auto-fill other fields if empty/different?
    // The user strictly asked for selections.
    // If I pick an item that is associated with a brand, it might be nice to set the brand.
    if (purchase.brand && (!brandSearch.value || brandSearch.value !== purchase.brand)) {
        brandSearch.value = purchase.brand
    }
    if (purchase.unit_measurement && (!unitSearch.value)) {
        unitSearch.value = purchase.unit_measurement
    }
    

}

// Unit Search Logic
const searchUnits = async (query: string) => {
    const q = (query || '').toLowerCase()
    const allUnits = mergeUnitsWithDefaults(receiptsStore.units)
    return allUnits.filter(u => u.name.toLowerCase().includes(q))
}

// Count Unit search function for SearchableInput
const searchCountUnits = async (query: string) => {
  const q = query.toLowerCase()
  return COUNT_UNIT_OPTIONS.filter(u => u.name.toLowerCase().includes(q))
}

const selectUnit = (unit: Unit) => {
    unitSearch.value = unit.name
    unitSearch.value = unit.name
}

const createAndSelectUnit = async (name: string) => {
    if (!name) return
    
    // 1. Check local
    let existing = receiptsStore.units.find(u => u.name.toLowerCase() === name.toLowerCase())
    
    // 2. Refresh if missing
    if (!existing) {
        await receiptsStore.fetchUnits()
        existing = receiptsStore.units.find(u => u.name.toLowerCase() === name.toLowerCase())
    }
    
    // 3. Select if found
    if (existing) {
        selectUnit(existing)
        return
    }
    
    // 4. Create
    try {
        const newUnit = await receiptsStore.createUnit(name)
        selectUnit(newUnit)
    } catch (e: any) {
        if (e.response?.status === 422) {
             // Handle race condition/duplicate gracefully
             const manualUnit = { 
                 id: 'temp', 
                 name: name,
                 household_id: 'temp',
                 inserted_at: new Date().toISOString(),
                 updated_at: new Date().toISOString()
             }
             selectUnit(manualUnit)
        } else {
             console.error("Failed to create unit", e)
        }
    }
}

// Lifecycle
onMounted(async () => {
    if (receiptsStore.brands.length === 0) await receiptsStore.fetchBrands()
    if (receiptsStore.units.length === 0) await receiptsStore.fetchUnits()
})

const handleSubmit = async () => {
  if (!props.store || !props.item) return

  loading.value = true
  error.value = ''

  try {
    const payload = {
      source: props.item.source,
      propagate: propagate.value,
      brand: form.value.brand,
      name: form.value.name,
      item: form.value.name,
      unit_measurement: form.value.unit,
      unit_of_measure: form.value.unit,
      price_per_unit: form.value.price,
      store_code: form.value.store_code,
      item_name: form.value.item_name,
      usage_mode: form.value.usage_mode
    }

    await receiptsStore.updateStoreInventoryItem(props.store.id, props.item.id, payload)
    
    emit('saved')
    emit('update:open', false)
  } catch (e: any) {
    error.value = e.message || 'Failed to update item'
  } finally {
    loading.value = false
  }
}


</script>

<template>
  <Dialog :open="open" @update:open="$emit('update:open', $event)">
    <DialogContent class="sm:max-w-[550px]">
      <DialogHeader>
        <DialogTitle>Edit Item</DialogTitle>
        <DialogDescription>
          Modify item details for this store.
        </DialogDescription>
      </DialogHeader>

      <div class="grid gap-6 py-4" v-if="item">
        <!-- Brand & Item Name -->
        <div class="grid grid-cols-2 gap-4 relative z-50">
          <div class="col-span-1 relative">
             <label class="text-sm font-medium mb-1.5 block">Brand</label>
              <SearchableInput 
                v-model="brandSearch"
                :search-function="searchBrands"
                :display-function="(b) => b.name"
                :value-function="(b) => b.name"
                :show-create-option="false" 
                :min-chars="0"
                placeholder="Brand name"
                @select="selectBrand"
              />
          </div>

          <div class="col-span-1 relative">
             <label class="text-sm font-medium mb-1.5 block">Item Name</label>
              <SearchableInput 
                v-model="itemSearch"
                :search-function="searchItems"
                :display-function="(p) => {
                    if (p.brand) return `${p.item} (${p.brand})`
                    return p.item
                }"
                :value-function="(p) => p.item"
                :show-create-option="false" 
                :min-chars="1"
                placeholder="Item name"
                @select="selectItem"
              />
          </div>
        </div>
        
        
        <!-- Store Code & Receipt Item Name -->
        <div class="grid grid-cols-2 gap-4 relative z-40 bg-muted/30 p-2 rounded-lg border border-border/50">
           <div class="col-span-1 relative">
            <label class="text-xs font-medium mb-1.5 block text-muted-foreground">Store Item Code</label>
            <Input 
                v-model="form.store_code" 
                placeholder="Code"
                autocomplete="off"
                class="h-8 text-sm"
            />
           </div>
           
           <div class="col-span-1 relative">
            <label class="text-xs font-medium mb-1.5 block text-muted-foreground">Store Item Name</label>
            <Input 
                v-model="form.item_name" 
                placeholder="Name on receipt"
                autocomplete="off"
                class="h-8 text-sm"
            />
           </div>
        </div>

        <!-- Row 1: Count (containers) + Count Unit -->
        <div class="grid grid-cols-2 gap-4 relative z-40">
          <div class="col-span-1 relative">
            <label class="text-sm font-medium mb-1.5 block">Count</label>
            <Input 
              v-model="form.quantity" 
              type="number" 
              step="any"
              min="0" 
              placeholder="# of boxes" 
            />
          </div>
          <div class="col-span-1 relative">
            <label class="text-sm font-medium mb-1.5 block">Count Unit</label>
            <SearchableInput 
              v-model="form.quantity_unit"
              :search-function="searchCountUnits"
              :display-function="(u) => u.name"
              :value-function="(u) => u.name"
              :show-create-option="false"
              :min-chars="0"
              placeholder="box, pack..."
            />
          </div>
        </div>

        <!-- Row 2: Quantity (weight/volume) + Quantity Unit -->
        <div class="grid grid-cols-2 gap-4 relative z-30">
          <div class="col-span-1 relative">
            <label class="text-sm font-medium mb-1.5 block">Quantity</label>
            <Input 
              v-model="form.count" 
              type="number" 
              step="any"
              min="0" 
              placeholder="e.g. 7 lbs" 
            />
          </div>
          <div class="col-span-1 relative">
            <label class="text-sm font-medium mb-1.5 block">Quantity Unit</label>
            <SearchableInput 
              v-model="form.count_unit"
              :search-function="searchUnits"
              :display-function="(u) => u.name"
              :value-function="(u) => u.name"
              :show-create-option="true"
              :min-chars="0"
              placeholder="lb, oz, ct..."
              @select="selectUnit"
              @create="createAndSelectUnit"
            />
          </div>
        </div>

        <!-- Price -->
        <div class="grid grid-cols-2 gap-4 relative z-20">
          <div class="col-span-1">
            <label class="text-sm font-medium mb-1.5 block">Price</label>
            <Input v-model="form.price" type="number" step="0.01" placeholder="0.00" />
          </div>
          <div class="col-span-1"></div>
        </div>

        <!-- Usage Mode Toggle -->
        <div class="relative z-10">
          <label class="text-sm font-medium mb-1.5 block">Usage Mode</label>
          <p class="text-xs text-muted-foreground mb-2">How is this item consumed?</p>
          <div class="flex rounded-lg border border-border overflow-hidden">
            <button
              type="button"
              class="flex-1 px-3 py-2 text-sm font-medium transition-colors"
              :class="form.usage_mode === 'count' ? 'bg-primary text-primary-foreground' : 'bg-muted/30 hover:bg-muted'"
              @click="form.usage_mode = 'count'"
            >
              By Count
            </button>
            <button
              type="button"
              class="flex-1 px-3 py-2 text-sm font-medium transition-colors border-l border-border"
              :class="form.usage_mode === 'quantity' ? 'bg-primary text-primary-foreground' : 'bg-muted/30 hover:bg-muted'"
              @click="form.usage_mode = 'quantity'"
            >
              By Quantity
            </button>
          </div>
          <p class="text-xs text-muted-foreground mt-1">
            {{ form.usage_mode === 'count' ? 'Consumed per container (1 box, 1 pack)' : 'Consumed by weight/volume (7 lbs potato, 16 oz cereal)' }}
          </p>
        </div>

        <div class="col-span-4 space-y-2 pt-2 border-t z-10">
          <div class="flex items-start gap-2">
            <Checkbox id="propagate" v-model="propagate" />
            <div class="grid gap-1.5 leading-none">
              <label
                for="propagate"
                class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70 cursor-pointer"
              >
                Update other items
              </label>
              <p class="text-xs text-muted-foreground">
                Apply changes to other "<strong>{{ props.item?.brand || 'Unknown' }}</strong>" items in this store that match the old values.
              </p>
            </div>
          </div>
        </div>

        <div v-if="error" class="col-span-4 text-center text-sm text-destructive">
          {{ error }}
        </div>
      </div>

      <DialogFooter>
        <Button variant="outline" @click="$emit('update:open', false)">Cancel</Button>
        <Button @click="handleSubmit" :disabled="loading">
          {{ loading ? 'Saving...' : 'Save Changes' }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
