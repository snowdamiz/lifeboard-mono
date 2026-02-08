<script setup lang="ts">
import { ref, onMounted, computed, watch, nextTick } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { X, Plus, PlusCircle, MinusCircle } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Checkbox } from '@/components/ui/checkbox'
import { useReceiptsStore } from '@/stores/receipts'
import { useTagsStore } from '@/stores/tags'
import { useInventoryStore } from '@/stores/inventory'
import TagManager from '@/components/shared/TagManager.vue'
import SearchableInput from '@/components/shared/SearchableInput.vue'
import { COUNT_UNIT_OPTIONS, mergeUnitsWithDefaults } from '@/utils/units'
import type { InventoryItem, Brand, Unit } from '@/types'

interface Props {
  item?: InventoryItem | null
}

const props = defineProps<Props>()
const emit = defineEmits<{
  close: []
  saved: []
}>()
const router = useRouter()
const route = useRoute()

const receiptsStore = useReceiptsStore()
const tagsStore = useTagsStore()
const inventoryStore = useInventoryStore()

const saving = ref(false)
const isEditing = computed(() => !!props.item)
const isProgrammaticUpdate = ref(false)

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

// Count Unit search function for SearchableInput
const searchCountUnits = async (query: string) => {
  const q = query.toLowerCase()
  return COUNT_UNIT_OPTIONS.filter(u => u.name.toLowerCase().includes(q))
}

// Unit search function for SearchableInput (unit of measure / count unit)
const searchUnits = async (query: string) => {
  const q = query.toLowerCase()
  const allUnits = mergeUnitsWithDefaults(receiptsStore.units)
  return allUnits.filter(u => u.name.toLowerCase().includes(q))
}

const form = ref({
  brand: props.item?.brand || '',
  name: props.item?.name || '',
  count: props.item?.count || '',
  count_unit: props.item?.count_unit || '',
  unit_of_measure: props.item?.unit_of_measure || '',
  quantity: props.item?.quantity ?? 0,
  min_quantity: props.item?.min_quantity ?? 0,
  store: props.item?.store || '',
  store_code: props.item?.store_code || '',
  item_name: props.item?.item_name || '',
  usage_mode: props.item?.usage_mode || 'count',
  tag_ids: props.item?.tags?.map(t => t.id) || [] as string[]
})

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

// Brand autocomplete watcher
watch(brandSearch, async (newValue) => {
  if (isSelecting.value) return

  if (!newValue) {
    brandSuggestions.value = receiptsStore.brands
    return
  }
  
  if (receiptsStore.brands.length > 0) {
    const search = newValue.toLowerCase()
    brandSuggestions.value = receiptsStore.brands.filter(b => 
      b.name.toLowerCase().includes(search)
    )
    if (!isProgrammaticUpdate.value) {
        showBrandDropdown.value = brandSuggestions.value.length > 0
    }
    return
  }

  // Fallback if needed, though usually brands are preloaded
  if (newValue.length >= 2) {
    loadingBrands.value = true
    try {
      brandSuggestions.value = await receiptsStore.searchBrands(newValue)
      if (!isProgrammaticUpdate.value) {
          showBrandDropdown.value = brandSuggestions.value.length > 0
      }
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

// ... other functions ...

onMounted(async () => {
    // Fetch data in parallel to ensure freshness (e.g. if new brands/stores were added in other views)
    await Promise.all([
        tagsStore.fetchTags(),
        receiptsStore.fetchBrands(),
        receiptsStore.fetchUnits(),
        receiptsStore.fetchStores()
    ])
  
  if (form.value.brand) {
    isProgrammaticUpdate.value = true
    brandSearch.value = form.value.brand
    await nextTick()
    isProgrammaticUpdate.value = false
  }
  if (form.value.unit_of_measure) {
    unitSearch.value = form.value.unit_of_measure
  }

  // Attempt to populate defaults if we have brand and store (even if editing)
  if (form.value.brand && form.value.store) {
      await checkAndApplyDefaults(form.value.brand, form.value.store)
  }
})

// ... existing imports ...

// ... inside script setup ...

const checkAndApplyDefaults = async (brandName: string, storeName: string) => {
  if (!brandName || !storeName) return

  const store = receiptsStore.stores.find(s => s.name.toLowerCase() === storeName.toLowerCase())
  const storeId = store?.id
  
  try {
      const suggestion = await receiptsStore.getSuggestionsByBrand(brandName, storeId)
      
      // If we have recent purchases, use the most recent one
      if (suggestion.recent_purchases && suggestion.recent_purchases.length > 0) {
          const latest = suggestion.recent_purchases[0]
          
          if (!form.value.name) form.value.name = latest.item
          if (!form.value.unit_of_measure && latest.unit_measurement) {
              form.value.unit_of_measure = latest.unit_measurement
              unitSearch.value = latest.unit_measurement
          }
          if (!form.value.store_code && latest.store_code) form.value.store_code = latest.store_code
          if (!form.value.item_name && latest.item_name) form.value.item_name = latest.item_name
      }
  } catch (e) {
      console.error("Failed to get brand suggestions", e)
  }
}

const selectBrand = async (brand: Brand) => {
  isSelecting.value = true
  form.value.brand = brand.name
  brandSearch.value = brand.name
  
  // Auto-population logic (Store + Brand)
  await checkAndApplyDefaults(brand.name, form.value.store)

  // Apply brand defaults if not already set by user or editing
  if (!isEditing.value) {
      if (brand.default_item && !form.value.name) {
          form.value.name = brand.default_item
      }
      if (brand.default_unit_measurement && !form.value.unit_of_measure) {
          form.value.unit_of_measure = brand.default_unit_measurement
          unitSearch.value = brand.default_unit_measurement
      }
      if (brand.default_tags && brand.default_tags.length > 0) {
          brand.default_tags.forEach(tagId => {
              const tag = tagsStore.tags.find(t => t.id === tagId)
              if (tag && !form.value.tag_ids.includes(tag.id)) {
                  form.value.tag_ids.push(tag.id)
              }
          })
      }
  }
  
  showBrandDropdown.value = false
  
  setTimeout(() => {
    isSelecting.value = false
  }, 100)
}

const handleBrandBlur = () => {
  setTimeout(() => {
    showBrandDropdown.value = false
  }, 200)
}

const selectUnit = (unit: Unit) => {
  form.value.unit_of_measure = unit.name
  unitSearch.value = unit.name
  showUnitDropdown.value = false
}

const createAndSelectUnit = async () => {
  if (!unitSearch.value) return
  
  // 1. Check local
  let existing = receiptsStore.units.find(u => u.name.toLowerCase() === unitSearch.value.toLowerCase())
  
  // 2. Refresh
  if (!existing) {
      await receiptsStore.fetchUnits()
      existing = receiptsStore.units.find(u => u.name.toLowerCase() === unitSearch.value.toLowerCase())
  }
  
  // 3. Select if found
  if (existing) {
      selectUnit(existing)
      return
  }

  // 4. Create
  try {
    const newUnit = await receiptsStore.createUnit(unitSearch.value)
    selectUnit(newUnit)
  } catch (error: any) {
    if (error.response?.status === 422) {
       form.value.unit_of_measure = unitSearch.value
       showUnitDropdown.value = false
    } else {
       console.warn('Failed to create unit:', error)
    }
  }
}

const searchStoreNames = async (query: string) => {
    const stores = await receiptsStore.searchStores(query)
    return stores.map(s => s.name)
}

// Watch unit search
watch(unitSearch, (newValue) => {
  form.value.unit_of_measure = newValue
})

const displayStore = (s: any) => {
    let text = s.name
    if (s.address) text += ` (${s.address})`
    if (s.store_code) text += ` [${s.store_code}]`
    return text
}

const onStoreSelect = (store: any) => {
    // Populate store code if available
    if (store.store_code) {
        form.value.store_code = store.store_code
    }
}

const handleStoreCreate = (name: string) => {
    router.push({
        path: '/budget/stores',
        query: {
            new: '1',
            name: name,
            returnTo: route.fullPath
        }
    })
}

// Bidirectional Sync Removed to avoid conflating Store ID with Item SKU

onMounted(async () => {
    // Fetch data in parallel to ensure freshness (e.g. if new brands/stores were added in other views)
    await Promise.all([
        tagsStore.fetchTags(),
        receiptsStore.fetchBrands(),
        receiptsStore.fetchUnits(),
        receiptsStore.fetchStores()
    ])
  
  if (form.value.brand) {
    brandSearch.value = form.value.brand
  }
  if (form.value.unit_of_measure) {
    unitSearch.value = form.value.unit_of_measure
  }

  // Attempt to populate defaults if we have brand and store (even if editing)
  if (form.value.brand && form.value.store) {
      await checkAndApplyDefaults(form.value.brand, form.value.store)
  }
})

const handleBrandFocus = () => {
  if (!brandSearch.value) {
    brandSuggestions.value = receiptsStore.brands
    showBrandDropdown.value = receiptsStore.brands.length > 0
  } else if (brandSearch.value.length >= 2) {
    showBrandDropdown.value = true
  }
}

const handleBrandEnter = (e: KeyboardEvent) => {
  if (showBrandDropdown.value && brandSuggestions.value.length > 0) {
    const exactMatch = brandSuggestions.value.find(
      b => b.name.toLowerCase() === brandSearch.value.toLowerCase()
    )
    if (exactMatch) {
      selectBrand(exactMatch)
      return
    }
    if (brandSearch.value.length >= 2) {
      selectBrand(brandSuggestions.value[0])
    }
  }
}

const save = async () => {
  if (!form.value.name.trim()) return
  
  saving.value = true
  
  try {
    const itemData = {
      name: form.value.name,
      brand: form.value.brand || null,
      count: form.value.count || null,
      count_unit: form.value.count_unit || null,
      unit_of_measure: form.value.unit_of_measure || null,
      quantity: form.value.quantity,
      min_quantity: form.value.min_quantity,
      store: form.value.store || null,
      store_code: form.value.store_code || null,
      item_name: form.value.item_name || null,
      usage_mode: form.value.usage_mode,
      tag_ids: form.value.tag_ids,
      // Ensure we preserve sheet_id if passed via props, 
      // primarily validation happens in store action via active sheet
      sheet_id: inventoryStore.currentSheet?.id 
    }

    if (form.value.unit_of_measure) {
      // Check local
      let existingUnit = receiptsStore.units.find(
        u => u.name.toLowerCase() === form.value.unit_of_measure.toLowerCase()
      )
      
      // If not local, refresh
      if (!existingUnit) {
          await receiptsStore.fetchUnits()
          existingUnit = receiptsStore.units.find(
            u => u.name.toLowerCase() === form.value.unit_of_measure.toLowerCase()
          )
      }

      // Only create if really missing
      if (!existingUnit) {
        try {
          await receiptsStore.createUnit(form.value.unit_of_measure)
        } catch (error: any) {
             if (error.response?.status !== 422) {
                 console.error('Unit creation failed', error)
             }
        }
      }
    }

    if (isEditing.value && props.item) {
      await inventoryStore.updateItem(props.item.id, itemData)
    } else if (inventoryStore.currentSheet?.id) {
        // Explicitly pass sheet_id for creation
       await inventoryStore.createItem({
           ...itemData,
           sheet_id: inventoryStore.currentSheet.id
       })
    }
    
    emit('saved')
    emit('close')
  } catch (e) {
      console.error(e)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 bg-background/80 backdrop-blur-sm z-[10000] flex items-end sm:items-center justify-center p-0 sm:p-4" @click="emit('close')">
      <div 
        class="w-full sm:max-w-md bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-xl overflow-hidden animate-slide-up max-h-[90vh] sm:max-h-[85vh] flex flex-col"
        @click.stop
      >
        <div class="flex items-center justify-between p-4 border-b border-border shrink-0">
          <h2 class="text-lg font-semibold">{{ isEditing ? 'Edit Item' : 'Add Item' }}</h2>
          <Button variant="ghost" size="icon" @click="emit('close')">
            <X class="h-4 w-4" />
          </Button>
        </div>

        <form class="flex-1 overflow-auto p-4 space-y-4" @submit.prevent="save">
          <!-- Store (Moved to Top) -->
          <div>
             <label class="text-sm font-medium">Store</label>
             <SearchableInput 
               v-model="form.store" 
               :search-function="searchStoreNames"
               :min-chars="1"
               placeholder="Where to buy" 
               class="mt-1" 
             />
          </div>

          <!-- Brand (with autocomplete) -->
          <div class="relative">
            <label class="text-sm font-medium">Brand</label>
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

          <!-- Extended Fields: Store Code & Receipt Item Name -->
          <div class="grid grid-cols-2 gap-3 p-3 bg-muted/30 rounded-lg border border-border/50">
              <div>
                  <label class="text-xs font-medium text-muted-foreground">Store</label>
                  <SearchableInput
                      v-model="form.store"
                      :search-function="receiptsStore.searchStores"
                      :display-function="displayStore"
                      :value-function="(s: any) => s.name"
                      placeholder="Store name (or type code)"
                      :min-chars="0"
                      :show-create-option="true"
                      @select="onStoreSelect"
                      @create="handleStoreCreate"
                  />
              </div>
              <div>
                  <label class="text-xs font-medium text-muted-foreground">Receipt Item Name</label>
                  <SearchableInput
                      v-model="form.item_name"
                      :search-function="receiptsStore.searchReceiptItemNames"
                      :min-chars="1"
                      placeholder="Receipt Name"
                      class="mt-1 h-8 text-sm"
                  />
              </div>
          </div>

          <!-- Item Name -->
          <div>
            <label class="text-sm font-medium">Name *</label>
            <SearchableInput 
              v-model="form.name" 
              :search-function="receiptsStore.searchItemNames"
              :min-chars="1"
              placeholder="Item name" 
              class="mt-1" 
            />
          </div>

          <!-- Row 1: Count (containers) + Count Unit -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm font-medium text-muted-foreground">Count</label>
              <Input 
                v-model="form.count" 
                type="number" 
                step="any"
                min="0" 
                placeholder="# of boxes" 
                class="mt-1" 
              />
            </div>
            <div>
              <label class="text-sm font-medium text-muted-foreground">Count Unit</label>
              <SearchableInput 
                v-model="form.count_unit"
                :search-function="searchCountUnits"
                :display-function="(u) => u.name"
                :value-function="(u) => u.name"
                :show-create-option="false"
                :min-chars="0"
                placeholder="box, pack..." 
                class="mt-1"
              />
            </div>
          </div>

          <!-- Row 2: Quantity (weight/volume) + Quantity Unit -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm font-medium text-muted-foreground">Quantity</label>
              <Input 
                v-model.number="form.quantity" 
                type="number" 
                step="any"
                min="0" 
                placeholder="e.g. 5 lbs" 
                class="mt-1" 
              />
            </div>
            <div>
              <label class="text-sm font-medium text-muted-foreground">Quantity Unit</label>
              <SearchableInput 
                v-model="form.unit_of_measure"
                :search-function="searchUnits"
                :display-function="(u) => u.name"
                :value-function="(u) => u.name"
                :show-create-option="true"
                :min-chars="0"
                placeholder="lb, oz, ct..." 
                class="mt-1"
                @create="createAndSelectUnit"
              />
            </div>
          </div>

          <!-- Min Qty (separate row) -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm font-medium text-muted-foreground">Min Quantity Alert</label>
              <Input 
                v-model.number="form.min_quantity" 
                type="number" 
                min="0" 
                placeholder="0" 
                class="mt-1" 
              />
            </div>
            <div></div>
          </div>

          <!-- Usage Mode Toggle -->
          <div>
            <label class="text-sm font-medium">Usage Mode</label>
            <p class="text-xs text-muted-foreground mb-2">How is this item consumed from inventory?</p>
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


          <!-- Tags -->
          <div>
            <label class="text-sm font-medium">Tags</label>
            <div class="flex flex-wrap gap-1.5 mb-2 mt-1" v-if="form.tag_ids.length > 0">
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
        
        <div class="flex gap-3 p-4 border-t border-border bg-card shrink-0">
          <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="emit('close')">
            Cancel
          </Button>
          <Button 
            type="submit" 
            class="flex-1 sm:flex-none sm:ml-auto" 
            :disabled="saving || !form.name" 
            @click="save"
          >
            {{ saving ? 'Saving...' : (isEditing ? 'Save Changes' : 'Add Item') }}
          </Button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
