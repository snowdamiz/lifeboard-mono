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

// Brand autocomplete
const brandSearch = ref('')
const brandSuggestions = ref<Brand[]>([])
const showBrandDropdown = ref(false)
const loadingBrands = ref(false)

// Unit autocomplete
const unitSearch = ref('')
const showUnitDropdown = ref(false)

const filteredUnits = computed(() => {
  if (!unitSearch.value) return receiptsStore.units
  const search = unitSearch.value.toLowerCase()
  return receiptsStore.units.filter(u => u.name.toLowerCase().includes(search))
})

const exactUnitMatch = computed(() => {
  if (!unitSearch.value) return false
  return receiptsStore.units.some(u => u.name.toLowerCase() === unitSearch.value.toLowerCase())
})

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

const form = ref({
  brand: props.purchase?.brand || '',
  item: props.purchase?.item || '',
  unit_measurement: props.purchase?.unit_measurement || '',
  count: props.purchase?.count || '',
  price_per_count: props.purchase?.price_per_count || '',
  units: props.purchase?.units || '',
  price_per_unit: props.purchase?.price_per_unit || '',
  taxable: props.purchase?.taxable ?? true,
  tax_rate: props.purchase?.tax_rate || '',
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

// Brand autocomplete
watch(brandSearch, async (newValue) => {
  if (isSelecting.value) return

  if (!newValue) {
    // Show all brands when empty
    brandSuggestions.value = receiptsStore.brands
    return
  }
  
  // Local filter first for better responsiveness if we have brands loaded
  if (receiptsStore.brands.length > 0) {
    const search = newValue.toLowerCase()
    brandSuggestions.value = receiptsStore.brands.filter(b => 
      b.name.toLowerCase().includes(search)
    )
    showBrandDropdown.value = brandSuggestions.value.length > 0
    return
  }

  // Fallback to API if for some reason we rely on that (though we load all on mount now)
  if (newValue.length >= 2) {
    loadingBrands.value = true
    try {
      brandSuggestions.value = await receiptsStore.searchBrands(newValue)
      showBrandDropdown.value = brandSuggestions.value.length > 0
    } catch (error: any) {
      brandSuggestions.value = []
      showBrandDropdown.value = false
    } finally {
      loadingBrands.value = false
    }
  } else {
    brandSuggestions.value = []
    showBrandDropdown.value = false
  }
})

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
  brandSearch.value = brand.name
  
  console.log('Selecting brand:', brand)
  
  // Track what we've set to avoid overwriting with older data if we implement a tiered fallback
  let itemSet = false
  let unitSet = false
  let tagsSet = false
  
  // 1. Try explicit Brand defaults first
  if (brand.default_item) {
    console.log('Setting default item from brand:', brand.default_item)
    form.value.item = brand.default_item
    itemSet = true
  }
  
  if (brand.default_unit_measurement) {
    console.log('Setting default unit from brand:', brand.default_unit_measurement)
    form.value.unit_measurement = brand.default_unit_measurement
    unitSearch.value = brand.default_unit_measurement
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

  // 2. Fallback to recent history if anything is missing OR to populate store-specific fields
  // We check history even if some defaults are set, because we might want store-specific overrides
  // or additional fields (store_code, item_name)
  
  const storeId = getStoreId()
  
  try {
      const suggestions = await receiptsStore.getSuggestionsByBrand(brand.name, storeId)
      if (suggestions && suggestions.recent_purchases && suggestions.recent_purchases.length > 0) {
        const lastPurchase = suggestions.recent_purchases[0]
        console.log('Using recent purchase for defaults:', lastPurchase)
        
        // If we found a store-specific purchase, we might want to prioritize it over generic brand defaults?
        // For now, let's fill gaps and populate store fields.
        
        if (!itemSet && lastPurchase.item) {
           form.value.item = lastPurchase.item
           itemSet = true
        }
        
        if (!unitSet && lastPurchase.unit_measurement) {
           form.value.unit_measurement = lastPurchase.unit_measurement
           unitSearch.value = lastPurchase.unit_measurement
           unitSet = true
        }

        // Also try to help with tax settings if they aren't standard
        if (lastPurchase.taxable !== undefined) {
           form.value.taxable = lastPurchase.taxable
        }
        
        if (!tagsSet && lastPurchase.tags && lastPurchase.tags.length > 0) {
           lastPurchase.tags.forEach(t => {
             // Tags from purchase might be objects or IDs depending on API normalization
             if (t.id && !form.value.tag_ids.includes(t.id)) {
                form.value.tag_ids.push(t.id)
             }
           })
        }
        
        // Store specific fields
        if (lastPurchase.store_code) {
          form.value.store_code = lastPurchase.store_code
        }
        
        if (lastPurchase.item_name) {
          form.value.item_name = lastPurchase.item_name
        }
      }
  } catch (err) {
      console.warn('Failed to fetch brand history for defaults:', err)
  }
  
  showBrandDropdown.value = false
  
  // Reset flag after updates propagate
  setTimeout(() => {
    isSelecting.value = false
  }, 100)
}

const handleBrandBlur = () => {
  // Delay hiding dropdown to allow click events to fire
  setTimeout(() => {
    showBrandDropdown.value = false
  }, 200)
}

const selectUnit = (unit: Unit) => {
  form.value.unit_measurement = unit.name
  unitSearch.value = unit.name
  showUnitDropdown.value = false
}

const createAndSelectUnit = async () => {
  if (!unitSearch.value) return
  const newUnit = await receiptsStore.createUnit(unitSearch.value)
  selectUnit(newUnit)
}

const handleUnitBlur = () => {
  setTimeout(() => {
    showUnitDropdown.value = false
  }, 200)
}

// Watch unit search to update form
watch(unitSearch, (newValue) => {
  form.value.unit_measurement = newValue
})

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

  // Fetch brands if needed
  if (receiptsStore.brands.length === 0) {
    await receiptsStore.fetchBrands()
  }

  // Load units
  if (receiptsStore.units.length === 0) {
    await receiptsStore.fetchUnits()
  }
  
  // Initialize brand search with current brand
  if (form.value.brand) {
    brandSearch.value = form.value.brand
  }

  // Initialize unit search
  if (form.value.unit_measurement) {
    unitSearch.value = form.value.unit_measurement
  }
})

const handleBrandFocus = () => {
  if (!brandSearch.value) {
    // Show all brands if search is empty
    brandSuggestions.value = receiptsStore.brands
    showBrandDropdown.value = receiptsStore.brands.length > 0
  } else if (brandSearch.value.length >= 2) {
    showBrandDropdown.value = true
  }
}

const handleBrandEnter = (e: KeyboardEvent) => {
  // If dropdown is visible and we have suggestions, select the first match or exact match
  if (showBrandDropdown.value && brandSuggestions.value.length > 0) {
    // Prefer exact match (case insensitive)
    const exactMatch = brandSuggestions.value.find(
      b => b.name.toLowerCase() === brandSearch.value.toLowerCase()
    )
    
    if (exactMatch) {
      selectBrand(exactMatch)
      return
    }
    
    // Otherwise select the first one if it's a "good enough" match?
    // For now let's just use the first suggestion if the user presses enter
    // but only if they've typed something relevant
    if (brandSearch.value.length >= 2) {
      selectBrand(brandSuggestions.value[0])
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
      const existingUnit = receiptsStore.units.find(
        u => u.name.toLowerCase() === form.value.unit_measurement.toLowerCase()
      )
      if (!existingUnit) {
        await receiptsStore.createUnit(form.value.unit_measurement)
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
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm z-[10000] flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="w-full sm:max-w-2xl bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[90vh] sm:max-h-[85vh] flex flex-col">
        <div class="flex items-center justify-between p-4 border-b border-border shrink-0">
          <h2 class="text-lg font-semibold">{{ isEditing ? 'Edit Purchase' : 'Add Purchase' }}</h2>
          <Button variant="ghost" size="icon" @click="emit('close')">
            <X class="h-4 w-4" />
          </Button>
        </div>

        <form class="flex-1 overflow-auto p-4 space-y-4" @submit.prevent="save">
          <!-- Brand (with autocomplete) -->
          <div class="relative">
            <label class="text-sm font-medium">Brand *</label>
            <Input 
              v-model="brandSearch" 
              @input="form.brand = brandSearch"
              @blur="handleBrandBlur"
              @focus="handleBrandFocus"
              @keydown.enter.prevent="handleBrandEnter"
              placeholder="Start typing brand name..." 
              class="mt-1" 
              autocomplete="off"
            />
            
            <!-- Brand suggestions dropdown -->
            <div 
              v-if="showBrandDropdown && brandSuggestions.length > 0" 
              class="absolute top-full left-0 right-0 mt-1 bg-popover border border-border rounded-lg shadow-lg z-10 max-h-60 overflow-auto"
            >
              <button
                v-for="brand in brandSuggestions"
                :key="brand.id"
                type="button"
                class="w-full text-left px-3 py-2 hover:bg-accent text-sm border-b border-border last:border-0"
                @click="selectBrand(brand)"
              >
                <div class="font-medium">{{ brand.name }}</div>
                <div v-if="brand.default_item" class="text-xs text-muted-foreground">
                  Default: {{ brand.default_item }}
                </div>
              </button>
            </div>
            
            <p v-if="loadingBrands" class="text-xs text-muted-foreground mt-1">Searching...</p>
          </div>

          <!-- Item -->
          <div>
            <label class="text-sm font-medium">Item *</label>
            <Input v-model="form.item" placeholder="e.g., Milk, Bread, etc." class="mt-1" />
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
              <div class="space-y-2">
                <!-- Unit Search/Create Input -->
                <div class="flex gap-2">
                  <Input 
                    v-model="unitSearch" 
                    placeholder="Search or create unit..." 
                    class="flex-1"
                    autocomplete="off"
                    @keydown.enter.prevent="createAndSelectUnit"
                  />
                  <Button 
                    type="button"
                    :disabled="!unitSearch || exactUnitMatch"
                    @click="createAndSelectUnit"
                    size="sm"
                    variant="outline"
                  >
                    <Plus class="h-4 w-4 mr-2" />
                    New
                  </Button>
                </div>
                
                <!-- Unit Selection List -->
                <div class="border border-border rounded-lg bg-card overflow-hidden max-h-40 overflow-y-auto">
                    <div v-if="filteredUnits.length > 0" class="divide-y divide-border">
                        <button
                            v-for="unit in filteredUnits"
                            :key="unit.id"
                            type="button"
                            class="w-full px-3 py-2 text-left hover:bg-secondary/60 flex items-center gap-2 transition-colors text-sm"
                            @click="selectUnit(unit)"
                        >
                            <div class="h-4 w-4 rounded-full border border-primary flex items-center justify-center">
                                <div v-if="form.unit_measurement === unit.name" class="h-2 w-2 rounded-full bg-primary" />
                            </div>
                            <span class="flex-1 font-medium">{{ unit.name }}</span>
                        </button>
                    </div>
                    <div v-else class="px-3 py-4 text-center text-xs text-muted-foreground">
                        {{ unitSearch ? 'No matching units found' : 'No units available' }}
                    </div>
                </div>
              </div>
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
              <label class="text-sm font-medium text-muted-foreground">Store Code</label>
              <Input 
                v-model="form.store_code" 
                placeholder="Receipt item code" 
                class="mt-1 font-mono text-xs" 
              />
            </div>
            <div>
              <label class="text-sm font-medium text-muted-foreground">Receipt Item Name</label>
              <Input 
                v-model="form.item_name" 
                placeholder="Name on receipt" 
                class="mt-1 text-xs" 
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
