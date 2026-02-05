<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { X, Plus, PlusCircle, MinusCircle } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Checkbox } from '@/components/ui/checkbox'
import { useReceiptsStore } from '@/stores/receipts'
import { useTagsStore } from '@/stores/tags'
import { useAuthStore } from '@/stores/auth'
import TagManager from '@/components/shared/TagManager.vue'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import type { Purchase, Brand, Unit } from '@/types'

interface Props {
  purchase?: Purchase | null
  stopId?: string | null
  initialDate?: string
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  saved: []
}>()

const receiptsStore = useReceiptsStore()
const tagsStore = useTagsStore()
const authStore = useAuthStore()

const saving = ref(false)
const isEditing = computed(() => !!props.purchase)




// Unit autocomplete helpers - shows defaults + custom units from store
import { mergeUnitsWithDefaults } from '@/utils/units'

const searchUnits = async (query: string) => {
  const q = query.toLowerCase()
  const allUnits = mergeUnitsWithDefaults(receiptsStore.units)
  return allUnits.filter(u => u.name.toLowerCase().includes(q))
}

const handleUnitCreate = async (name: string) => {
  if (!name) return
  
  // 1. Check local store first
  let existing = receiptsStore.units.find(u => u.name.toLowerCase() === name.toLowerCase())
  
  // 2. If not found, refresh store to be sure
  if (!existing) {
    try {
      await receiptsStore.fetchUnits()
      existing = receiptsStore.units.find(u => u.name.toLowerCase() === name.toLowerCase())
    } catch (e) {
      console.error('Failed to refresh units:', e)
    }
  }
  
  // 3. If found now, just use it
  if (existing) {
    form.value.unit_measurement = existing.name
    return
  }

  // 4. If still not found, try to create
  try {
    await receiptsStore.createUnit(name)
    form.value.unit_measurement = name
  } catch (error: any) {
    // If we still hit a 422 (e.g. race condition), handled gracefully
    if (error.response?.status === 422 || error.message?.includes('already exist')) {
       form.value.unit_measurement = name
    } else {
       console.error('Failed to create unit:', error)
    }
  }
}

const handleBrandCreate = async (name: string) => {
  if (!name.trim()) return
  const existing = receiptsStore.brands.find(b => b.name.toLowerCase() === name.trim().toLowerCase())
  if (existing) {
    form.value.brand = existing.name
    await selectBrand(existing)
    return
  }
  try {
    const brand = await receiptsStore.createBrand({ name })
    form.value.brand = brand.name
    await selectBrand(brand)
  } catch (e) {
    console.error('Failed to create brand', e)
  }
}

const handleItemCreate = async (name: string) => {
  if (!name.trim()) return
  form.value.item = name.trim()
}

const handleStoreCodeCreate = async (code: string) => {
  if (!code.trim()) return
  form.value.store_code = code.trim()
}

const handleItemNameCreate = async (name: string) => {
  if (!name.trim()) return
  form.value.item_name = name.trim()
}

// Form data
// Helper to extract pre-tax price from stored total
const getInitialPrice = () => {
  if (!props.purchase?.total_price) return ''
  
  const total = parseFloat(props.purchase.total_price)
  const taxRate = parseFloat(props.purchase.tax_rate as any) || 0
  
  if (props.purchase.taxable && taxRate > 0) {
    return (total / (1 + taxRate / 100)).toFixed(2)
  }
  return props.purchase.total_price
}

// Helper to compute price per count if not stored
const getInitialPricePerCount = () => {
  // If explicitly stored, use it
  if (props.purchase?.price_per_count) {
    return props.purchase.price_per_count
  }
  // Derive from total_price and count if available
  const preTaxTotal = parseFloat(getInitialPrice()) || 0
  const count = parseFloat(props.purchase?.count as any) || 0
  if (preTaxTotal > 0 && count > 0) {
    return (preTaxTotal / count).toFixed(2)
  }
  return ''
}

// Helper to compute price per unit if not stored
const getInitialPricePerUnit = () => {
  // If explicitly stored, use it
  if (props.purchase?.price_per_unit) {
    return props.purchase.price_per_unit
  }
  // Derive from total_price and units if available
  const preTaxTotal = parseFloat(getInitialPrice()) || 0
  const units = parseFloat(props.purchase?.units as any) || 0
  if (preTaxTotal > 0 && units > 0) {
    return (preTaxTotal / units).toFixed(2)
  }
  return ''
}

// Helper to compute tax rate as percentage
const getInitialTaxRate = () => {
  if (!props.purchase?.tax_rate) return ''
  const rate = parseFloat(props.purchase.tax_rate as any)
  // Tax rate could be stored as decimal (0.0825) or percentage (8.25)
  // If it's less than 1, assume it's a decimal and convert to percentage
  if (rate > 0 && rate < 1) {
    return (rate * 100).toFixed(2)
  }
  return props.purchase.tax_rate
}

const form = ref({
  brand: props.purchase?.brand || '',
  item: props.purchase?.item || '',
  unit_measurement: props.purchase?.unit_measurement || '',
  count: props.purchase?.count || '',
  price_per_count: getInitialPricePerCount(),
  units: props.purchase?.units || '',
  price_per_unit: getInitialPricePerUnit(),
  taxable: props.purchase?.taxable ?? true,
  tax_rate: getInitialTaxRate(),
  total_price: getInitialPrice(),
  store_code: props.purchase?.store_code || '',
  item_name: props.purchase?.item_name || '',
  tag_ids: props.purchase?.tags?.map(t => t.id) || [] as string[],
  stop_id: props.stopId || props.purchase?.stop_id || null,
  date: props.initialDate || new Date().toISOString().split('T')[0]
})

const taxableId = `taxable-${Math.random().toString(36).substring(2, 9)}`

// Tag Management
const checkedTagIds = ref<Set<string>>(new Set())
const tagManagerRef = ref<InstanceType<typeof TagManager> | null>(null)

const addCheckedTags = () => {
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

// Tag helpers
const getTagById = (tagId: string) => {
  return tagsStore.tags.find(t => t.id === tagId)
}

const getTagStyle = (tagId: string) => {
  const tag = getTagById(tagId)
  if (!tag) return {}
  return { 
    backgroundColor: tag.color + '20', 
    color: tag.color, 
    borderColor: tag.color + '40' 
  }
}

const getTagColor = (tagId: string) => {
  const tag = getTagById(tagId)
  return tag?.color || '#64748b'
}

const getTagName = (tagId: string) => {
  const tag = getTagById(tagId)
  return tag?.name || 'Unknown'
}

const isSelecting = ref(false)



// Helper to finding store ID from stop ID
const getStoreId = () => {
  if (!props.stopId) return undefined
  
  // Check current trip first
  if (receiptsStore.currentTrip) {
    const stop = receiptsStore.currentTrip.stops.find(s => s.id === props.stopId)
    if (stop?.store_id) return stop.store_id
  }
  
  // Check all trips
  for (const trip of receiptsStore.trips) {
    const stop = trip.stops.find(s => s.id === props.stopId)
    if (stop?.store_id) return stop.store_id
  }
  
  return undefined
}

const selectBrand = async (brand: Brand) => {
  isSelecting.value = true
  form.value.brand = brand.name

  
  console.log('Selecting brand:', brand)
  
  // Track what we've set
  let itemSet = false
  let unitSet = false
  let tagsSet = false
  
  // 1. Try explicit Brand defaults first
  if (brand.default_item) {
    form.value.item = brand.default_item
    itemSet = true
  }
  
  if (brand.default_unit_measurement) {
    form.value.unit_measurement = brand.default_unit_measurement
    unitSet = true
  }
  
  if (brand.default_tags && brand.default_tags.length > 0) {
    brand.default_tags.forEach(tagId => {
      const tag = tagsStore.tags.find(t => t.id === tagId)
      if (tag && !form.value.tag_ids.includes(tag.id)) {
        form.value.tag_ids.push(tag.id)
      }
    })
    tagsSet = true
  }

  // 2. Fetch History (Store-specific + Global fallback/merge)
  const storeId = getStoreId()
  let history: Purchase[] = []
  
  try {
    // A. Store-specific
    if (storeId) {
      const res = await receiptsStore.getSuggestionsByBrand(brand.name, storeId)
      if (res?.recent_purchases) {
        history = res.recent_purchases
      }
    }

    // B. Global fallback/fill: if no history or missing key fields
    const hasStoreCode = history.some(p => p.store_code)
    const hasItemName = history.some(p => p.item_name)
    
    if (!storeId || history.length === 0 || !hasStoreCode || !hasItemName) {
         console.log('Fetching global history to fill gaps')
         const globalRes = await receiptsStore.getSuggestionsByBrand(brand.name)
         if (globalRes?.recent_purchases) {
            // Append global purchases (lower priority than store-specific)
            const existingIds = new Set(history.map(p => p.id))
            const newGlobals = globalRes.recent_purchases.filter(p => !existingIds.has(p.id))
            history = [...history, ...newGlobals]
         }
    }
  } catch (err) {
      console.warn('Failed to fetch brand history:', err)
  }

  // 3. Apply defaults from history
  if (history.length > 0) {
       console.log('Applying defaults from history:', history.length, 'entries')
       // Helper to find first non-empty value
       const findVal = <K extends keyof Purchase>(key: K): Purchase[K] | undefined => {
          const val = history.find(p => p[key])?.[key]
          return val
       }

       if (!itemSet) {
          const val = findVal('item')
          if (val && typeof val === 'string') { 
              console.log('Found item in history:', val); 
              form.value.item = val; 
              itemSet = true; 
          }
       }
       
       if (!unitSet) {
          const val = findVal('unit_measurement')
          if (val && typeof val === 'string') { 
              console.log('Found unit_measurement in history:', val)
              form.value.unit_measurement = val
              unitSet = true
          }
       }

       // For tax, take from most recent relevant purchase
       const latest = history[0]
       if (latest.taxable !== undefined) {
          form.value.taxable = latest.taxable
       }
       
       if (!tagsSet) {
           // Collect unique tags from recent history? Or just most recent?
           // Let's stick to the most recent purchase that has tags
           const pWithTags = history.find(p => p.tags && p.tags.length > 0)
           if (pWithTags && pWithTags.tags) {
               pWithTags.tags.forEach(t => {
                   // t might be object or ID depending on API
                   const tId = typeof t === 'object' ? t.id : t
                   if (tId && !form.value.tag_ids.includes(tId)) {
                       form.value.tag_ids.push(tId)
                   }
               })
           }
       }
       
       // Store fields - search whole history
       console.log('Looking for store fields in history:', history.length, 'purchases')
       const code = findVal('store_code')
       if (code && typeof code === 'string') {
           console.log('Found store_code:', code)
           form.value.store_code = code
       }
       
       const name = findVal('item_name')
       if (name && typeof name === 'string') {
           console.log('Found item_name:', name)
           form.value.item_name = name
       }
  }
  
  applyStoreTaxRate()
  
  setTimeout(() => {
    isSelecting.value = false
  }, 100)
}



// Calculate total price
const calculateTotal = () => {
  const count = parseFloat(form.value.count) || 0
  const pricePerCount = parseFloat(form.value.price_per_count) || 0
  const units = parseFloat(form.value.units) || 0
  const pricePerUnit = parseFloat(form.value.price_per_unit) || 0
  
  let subtotal = 0
  if (count && pricePerCount) {
    subtotal = count * pricePerCount
  } else if (units && pricePerUnit) {
    subtotal = units * pricePerUnit
  }
  
  // if (form.value.taxable && form.value.tax_rate) {
  //   const taxRate = parseFloat(form.value.tax_rate) || 0
  //   subtotal = subtotal * (1 + taxRate / 100)
  // }
  
  form.value.total_price = subtotal.toFixed(2)
}

// Watch pricing fields for auto-calculation
watch([
  () => form.value.count, 
  () => form.value.price_per_count, 
  () => form.value.units, 
  () => form.value.price_per_unit,
  () => form.value.taxable,
  () => form.value.tax_rate
], calculateTotal)

onMounted(async () => {
  if (tagsStore.tags.length === 0) {
    await tagsStore.fetchTags()
  }
  
  // Ensure stores are loaded for tax rate lookup
  if (receiptsStore.stores.length === 0) {
    await receiptsStore.fetchStores()
  }

  // Fetch brands if needed
  if (receiptsStore.brands.length === 0) {
    await receiptsStore.fetchBrands()
  }

  // Load units
  if (receiptsStore.units.length === 0) {
    await receiptsStore.fetchUnits()
  }
  
  // Initialize brand search - no longer needed as separate ref

  // Initialize unit search - no longer needed as separate ref
  
  // Try to set default tax rate from store if not set
  applyStoreTaxRate()
})

const applyStoreTaxRate = () => {
  if (form.value.taxable && !form.value.tax_rate) {
    const storeId = getStoreId()
    if (storeId) {
      const store = receiptsStore.stores.find(s => s.id === storeId)
      if (store && store.tax_rate) {
        const rate = parseFloat(store.tax_rate) * 100
        form.value.tax_rate = rate.toString()
      }
    }
  }
}



const save = async () => {
  if (!form.value.brand || !form.value.item || !form.value.total_price) {
    return
  }
  
  saving.value = true
  
  try {
    const purchaseData = {
      brand: form.value.brand,
      item: form.value.item,
      unit_measurement: form.value.unit_measurement || null,
      count: form.value.count || null,
      price_per_count: form.value.price_per_count || null,
      units: form.value.units || null,
      price_per_unit: form.value.price_per_unit || null,
      taxable: form.value.taxable,
      tax_rate: form.value.taxable ? (form.value.tax_rate || null) : null,
      total_price: (() => {
        const subtotal = parseFloat(form.value.total_price) || 0
        const taxRate = parseFloat(form.value.tax_rate) || 0
        if (form.value.taxable && taxRate > 0) {
          return (subtotal * (1 + taxRate / 100)).toFixed(2)
        }
        return form.value.total_price
      })(),
      store_code: form.value.store_code || null,
      item_name: form.value.item_name || null,
      tag_ids: form.value.tag_ids,
      stop_id: form.value.stop_id,
      date: form.value.date
    }
    
    // Create unit if it doesn't exist and we have a value
    if (form.value.unit_measurement) {
      // Check local
      let existingUnit = receiptsStore.units.find(
        u => u.name.toLowerCase() === form.value.unit_measurement.toLowerCase()
      )
      
      // If not local, refresh and check again
      if (!existingUnit) {
         await receiptsStore.fetchUnits()
         existingUnit = receiptsStore.units.find(
            u => u.name.toLowerCase() === form.value.unit_measurement.toLowerCase()
         )
      }

      // Only create if really missing
      if (!existingUnit) {
        try {
          await receiptsStore.createUnit(form.value.unit_measurement)
        } catch (error: any) {
          // Ignore if it's a duplicate error
          if (error.response?.status !== 422) {
             console.error('Unit creation failed', error)
          }
        }
      }
    }

    if (isEditing.value && props.purchase) {
      await receiptsStore.updatePurchase(props.purchase.id, purchaseData)
    } else {
      await receiptsStore.createPurchase(purchaseData)
    }
    
    emit('saved')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4" style="z-index: 60;">
      <div class="w-full sm:max-w-2xl bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[90vh] sm:max-h-[85vh] flex flex-col">
        <div class="flex items-center justify-between p-4 border-b border-border shrink-0">
          <h2 class="text-lg font-semibold">{{ isEditing ? 'Edit Purchase' : 'Add Purchase' }}</h2>
          <Button variant="ghost" size="icon" @click="emit('close')">
            <X class="h-4 w-4" />
          </Button>
        </div>

        <form class="flex-1 overflow-auto p-4 space-y-4" @submit.prevent="save">
          <!-- Brand (with autocomplete) -->
          <div>
            <label class="text-sm font-medium">Brand *</label>
            <SearchableInput 
              v-model="form.brand" 
              :search-function="(q) => receiptsStore.searchBrands(q)"
              :display-function="(b) => b.name"
              :value-function="(b) => b.name"
              :show-create-option="true"
              :min-chars="0"
              placeholder="Search or create brand..." 
              class="mt-1" 
              @select="selectBrand"
              @create="handleBrandCreate"
            />
          </div>

          <!-- Item -->
          <div>
            <label class="text-sm font-medium">Item *</label>
            <SearchableInput 
              v-model="form.item" 
              :search-function="receiptsStore.searchItemNames"
              :show-create-option="true"
              :min-chars="0"
              placeholder="Search or create item..." 
              class="mt-1"
              @create="handleItemCreate"
            />
          </div>

          <!-- Pricing Grid -->
          <div class="grid grid-cols-2 gap-3">
            <!-- Count-based pricing -->
            <div>
              <label class="text-sm font-medium text-muted-foreground">Count</label>
              <Input 
                v-model="form.count" 
                type="number" 
                step="any" 
                min="0" 
                placeholder="0" 
                class="mt-1" 
              />
            </div>
            <div>
              <label class="text-sm font-medium text-muted-foreground">Price/Count</label>
              <Input 
                v-model="form.price_per_count" 
                type="number" 
                step="0.01" 
                min="0" 
                placeholder="0.00" 
                class="mt-1" 
              />
            </div>

            <!-- Unit-based pricing -->
            <div>
              <label class="text-sm font-medium text-muted-foreground">Units</label>
              <Input 
                v-model="form.units" 
                type="number" 
                step="any" 
                min="0" 
                placeholder="0" 
                class="mt-1" 
              />
            </div>
            <div>
              <label class="text-sm font-medium text-muted-foreground">Price/Unit</label>
              <Input 
                v-model="form.price_per_unit" 
                type="number" 
                step="0.01" 
                min="0" 
                placeholder="0.00" 
                class="mt-1" 
              />
            </div>
          </div>

          <!-- Unit Measurement & Total Price -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm font-medium">Unit Measurement</label>
              <SearchableInput 
                v-model="form.unit_measurement"
                :search-function="searchUnits"
                :display-function="(u) => u.name"
                :value-function="(u) => u.name"
                :show-create-option="true"
                :min-chars="0"
                placeholder="Search or create unit..." 
                class="mt-1"
                @create="handleUnitCreate"
              />

            </div>
            <div>
              <label class="text-sm font-medium">Total Price *</label>
              <Input 
                v-model="form.total_price" 
                type="number" 
                step="0.01" 
                min="0" 
                placeholder="0.00" 
                class="mt-1 font-semibold" 
              />
            </div>
          </div>

          <!-- Taxable Checkbox -->
          <div class="flex items-center gap-2">
            <Checkbox 
              :id="taxableId"
              v-model="form.taxable" 
            />
            <label 
              v-if="!form.taxable"
              :for="taxableId"
              class="text-sm font-medium cursor-pointer"
            >
              Taxable item
            </label>
            <div v-else class="flex items-center gap-1.5 animate-fade-in">
              <Input
                v-model="form.tax_rate"
                type="number"
                step="0.1"
                min="0"
                placeholder="Tax"
                class="h-7 w-20 px-2 text-xs"
                @click.stop
              />
              <span class="text-xs font-medium">% Tax</span>
            </div>
          </div>

          <!-- Store Code & Item Name -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm font-medium text-muted-foreground">Store Item Code</label>
              <SearchableInput 
                v-model="form.store_code" 
                :search-function="receiptsStore.searchStoreCodes"
                :show-create-option="true"
                :min-chars="0"
                placeholder="Search or create code..." 
                class="mt-1 font-mono text-xs"
                @create="handleStoreCodeCreate"
              />
            </div>
            <div>
              <label class="text-sm font-medium text-muted-foreground">Store Item Name</label>
              <SearchableInput 
                v-model="form.item_name" 
                :search-function="receiptsStore.searchReceiptItemNames"
                :show-create-option="true"
                :min-chars="0"
                placeholder="Search or create name..." 
                class="mt-1 text-xs"
                @create="handleItemNameCreate"
              />
            </div>
          </div>

          <!-- Tags -->
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
        </form>
        
        <!-- Fixed Footer -->
        <div class="flex gap-3 p-4 border-t border-border bg-card shrink-0">
          <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="emit('close')">
            Cancel
          </Button>
          <Button 
            type="submit" 
            class="flex-1 sm:flex-none sm:ml-auto" 
            :disabled="saving || !form.brand || !form.item || !form.total_price" 
            @click="save"
          >
            {{ saving ? 'Saving...' : (isEditing ? 'Update Purchase' : 'Add Purchase') }}
          </Button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
