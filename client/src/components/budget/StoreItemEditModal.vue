<script setup lang="ts">
import { ref, watch, computed, onMounted } from 'vue'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription } from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Checkbox } from '@/components/ui/checkbox'
import { Plus, X } from 'lucide-vue-next'
import type { Store, Brand, Unit, Purchase } from '@/types'
import { useReceiptsStore } from '@/stores/receipts'

interface InventoryItem {
  id: string
  source: string
  brand: string | null
  name: string
  unit: string | null
  price: string | null
  date: string
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
})

// Search States
const brandSearch = ref('')
const showBrandDropdown = ref(false)
const brandSuggestions = ref<Brand[]>([])
const loadingBrands = ref(false)

const itemSearch = ref('')
const showItemDropdown = ref(false)
const itemSuggestions = ref<Purchase[]>([]) // Flattened suggestions
const loadingItems = ref(false)

const unitSearch = ref('')
const showUnitDropdown = ref(false)

// Bulk update state
const propagate = ref(true)

// Initialize form and search states
watch(() => props.item, (newItem) => {
  if (newItem) {
    form.value = {
      brand: newItem.brand || '',
      name: newItem.name,
      unit: newItem.unit || '',
      price: newItem.price || ''
    }
    brandSearch.value = newItem.brand || ''
    itemSearch.value = newItem.name
    unitSearch.value = newItem.unit || ''
  } else {
    form.value = {
      brand: '',
      name: '',
      unit: '',
      price: ''
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
watch(brandSearch, async (newValue) => {
  if (!newValue) {
    brandSuggestions.value = receiptsStore.brands
    return
  }
  
  if (receiptsStore.brands.length > 0) {
    const search = newValue.toLowerCase()
    brandSuggestions.value = receiptsStore.brands.filter(b => 
      b.name.toLowerCase().includes(search)
    )
    showBrandDropdown.value = brandSuggestions.value.length > 0
    return
  }
  
  if (newValue.length >= 2) {
    loadingBrands.value = true
    try {
      brandSuggestions.value = await receiptsStore.searchBrands(newValue)
      showBrandDropdown.value = brandSuggestions.value.length > 0
    } catch (e) {
      brandSuggestions.value = []
    } finally {
      loadingBrands.value = false
    }
  } else {
    brandSuggestions.value = []
  }
})

const handleBrandFocus = () => {
    if (!brandSearch.value) {
        brandSuggestions.value = receiptsStore.brands
        showBrandDropdown.value = receiptsStore.brands.length > 0
    } else {
        showBrandDropdown.value = brandSuggestions.value.length > 0
    }
}

const selectBrand = (brand: Brand) => {
    brandSearch.value = brand.name
    showBrandDropdown.value = false
}

// Item Search Logic
watch(itemSearch, async (newValue) => {
    if (!newValue || newValue.length < 2) {
        itemSuggestions.value = []
        showItemDropdown.value = false
        return
    }

    loadingItems.value = true
    try {
        const results = await receiptsStore.getSuggestionsByItem(newValue)
        // Flatten results to a list of purchases/items
        const flat: Purchase[] = []
        results.forEach(res => {
            if (res.recent_purchases) {
                flat.push(...res.recent_purchases)
            }
        })
        
        // Deduplicate by item name (and maybe brand?)
        // Let's just keep unique item names for now, or allow displaying "Item (Brand)"
        const unique = new Map<string, Purchase>()
        flat.forEach(p => {
             const key = `${p.item}-${p.brand}`
             if (!unique.has(key)) {
                 unique.set(key, p)
             }
        })
        
        itemSuggestions.value = Array.from(unique.values()).slice(0, 10)
        showItemDropdown.value = itemSuggestions.value.length > 0
    } catch (e) {
        itemSuggestions.value = []
    } finally {
        loadingItems.value = false
    }
})

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
    
    showItemDropdown.value = false
}

// Unit Search Logic
const filteredUnits = computed(() => {
    if (!unitSearch.value) return receiptsStore.units
    const search = unitSearch.value.toLowerCase()
    return receiptsStore.units.filter(u => u.name.toLowerCase().includes(search))
})

const selectUnit = (unit: Unit) => {
    unitSearch.value = unit.name
    showUnitDropdown.value = false
}

const createAndSelectUnit = async () => {
    if (!unitSearch.value) return
    // Check if exists
    const existing = receiptsStore.units.find(u => u.name.toLowerCase() === unitSearch.value?.toLowerCase())
    if (existing) {
        selectUnit(existing)
        return
    }
    
    try {
        const newUnit = await receiptsStore.createUnit(unitSearch.value)
        selectUnit(newUnit)
    } catch (e) {
        console.error("Failed to create unit", e)
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
      price_per_unit: form.value.price
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

const handleBrandBlur = () => {
    setTimeout(() => {
        showBrandDropdown.value = false
    }, 200)
}

const handleItemBlur = () => {
    setTimeout(() => {
        showItemDropdown.value = false
    }, 200)
}

const handleUnitBlur = () => {
    setTimeout(() => {
        showUnitDropdown.value = false
    }, 200)
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
              <Input 
                v-model="brandSearch" 
                placeholder="Brand name" 
                @focus="handleBrandFocus"
                @blur="handleBrandBlur"
                autocomplete="off"
              />
              <div 
                v-if="showBrandDropdown && brandSuggestions.length > 0"
                class="absolute top-full left-0 right-0 mt-1 bg-popover border border-border rounded-lg shadow-lg max-h-48 overflow-auto z-50"
              >
                  <button
                    v-for="brand in brandSuggestions"
                    :key="brand.id"
                    type="button"
                    class="w-full text-left px-3 py-2 hover:bg-accent text-sm border-b border-border last:border-0"
                    @click="selectBrand(brand)"
                  >
                    {{ brand.name }}
                  </button>
              </div>
          </div>

          <div class="col-span-1 relative">
             <label class="text-sm font-medium mb-1.5 block">Item Name</label>
              <Input 
                v-model="itemSearch" 
                placeholder="Item name" 
                @focus="showItemDropdown = itemSuggestions.length > 0"
                @blur="handleItemBlur"
                autocomplete="off"
              />
              <div 
                v-if="showItemDropdown && itemSuggestions.length > 0"
                class="absolute top-full left-0 right-0 mt-1 bg-popover border border-border rounded-lg shadow-lg max-h-48 overflow-auto z-50"
              >
                  <button
                    v-for="p in itemSuggestions"
                    :key="p.id"
                    type="button"
                    class="w-full text-left px-3 py-2 hover:bg-accent text-sm border-b border-border last:border-0"
                    @click="selectItem(p)"
                  >
                    <div class="font-medium">{{ p.item }}</div>
                    <div class="text-xs text-muted-foreground" v-if="p.brand">
                        {{ p.brand }} {{ p.unit_measurement ? `(${p.unit_measurement})` : '' }}
                    </div>
                  </button>
              </div>
          </div>
        </div>
        
        <!-- Unit & Price -->
        <div class="grid grid-cols-2 gap-4 relative z-40">
           <div class="col-span-1 relative">
            <label class="text-sm font-medium mb-1.5 block">Unit</label>
            <div class="flex gap-2">
                <Input 
                    v-model="unitSearch" 
                    placeholder="e.g. oz, gal"
                    @focus="showUnitDropdown = true"
                    @blur="handleUnitBlur" 
                    autocomplete="off"
                    @keydown.enter.prevent="createAndSelectUnit"
                    class="flex-1"
                />
            </div>
            
            <div 
                v-if="showUnitDropdown"
                class="absolute top-full left-0 right-0 mt-1 bg-popover border border-border rounded-lg shadow-lg max-h-48 overflow-auto z-50"
            >
                <div v-if="filteredUnits.length > 0">
                     <button
                        v-for="unit in filteredUnits"
                        :key="unit.id"
                        type="button"
                        class="w-full text-left px-3 py-2 hover:bg-accent text-sm border-b border-border last:border-0"
                        @click="selectUnit(unit)"
                     >
                        {{ unit.name }}
                     </button>
                </div>
                 <div v-else class="p-2 text-center text-xs text-muted-foreground">
                    <Button variant="ghost" size="sm" class="w-full h-auto py-1" @click="createAndSelectUnit">
                        Create "{{ unitSearch }}"
                    </Button>
                </div>
            </div>
          </div>
          
          <div class="col-span-1">
             <label class="text-sm font-medium mb-1.5 block">Price</label>
             <Input v-model="form.price" type="number" step="0.01" placeholder="0.00" />
          </div>
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
