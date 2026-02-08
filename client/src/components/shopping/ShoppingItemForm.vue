<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
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
import type { ShoppingListItem, Brand, Unit } from '@/types'
import { COUNT_UNIT_OPTIONS, mergeUnitsWithDefaults } from '@/utils/units'

interface Props {
  item?: ShoppingListItem | null
  listId: string
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

// Brand autocomplete
const brandSearch = ref('')

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

// Form data - mapped from ShoppingListItem or defaults
const form = ref({
  // Cast item to any to check for fields that might be returned by backend but not in strict type yet
  brand: (props.item as any)?.brand || '',
  name: props.item?.name || props.item?.inventory_item?.name || '',
  unit_of_measure: (props.item as any)?.unit_of_measure || '',
  quantity: props.item?.quantity_needed ?? 1,
  quantity_unit: (props.item as any)?.quantity_unit || '',
  count: (props.item as any)?.count || '',
  count_unit: (props.item as any)?.count_unit || '',
  min_quantity: 0, 
  store: (props.item as any)?.store || props.item?.inventory_item?.store || '',
  store_code: (props.item as any)?.store_code || '',
  item_name: (props.item as any)?.item_name || '',
  usage_mode: (props.item as any)?.usage_mode || 'count',
  tag_ids: ((props.item as any)?.tag_ids || []) as string[]
})

// Count Unit search function for SearchableInput
const searchCountUnits = async (query: string) => {
  const q = query.toLowerCase()
  return COUNT_UNIT_OPTIONS.filter(u => u.name.toLowerCase().includes(q))
}

// Unit search function for SearchableInput
const searchUnits = async (query: string) => {
  const q = query.toLowerCase()
  const allUnits = mergeUnitsWithDefaults(receiptsStore.units)
  return allUnits.filter(u => u.name.toLowerCase().includes(q))
}

// Brand search function for SearchableInput
const searchBrandsForInput = async (query: string) => {
  if (!query) return receiptsStore.brands
  const search = query.toLowerCase()
  const local = receiptsStore.brands.filter(b => b.name.toLowerCase().includes(search))
  if (local.length > 0) return local
  if (query.length >= 2) {
    try {
      return await receiptsStore.searchBrands(query)
    } catch { return [] }
  }
  return []
}

// Initialize from existing item if possible
if (props.item) {
    if (props.item.inventory_item) {
        // If we have a linked inventory item, we might want to fetch it to get full details?
        // For now, let's just use what we have. 
        // Note: ShoppingListItem only has limited fields.
    }
}

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

// Sync form.brand when brandSearch changes (from typing)
watch(brandSearch, (newVal) => {
  form.value.brand = newVal
})

const selectBrand = async (brand: Brand) => {
  isSelecting.value = true
  form.value.brand = brand.name
  brandSearch.value = brand.name
  
  // Auto-population logic (Store + Brand)
  if (form.value.store) {
      // Try to find store ID
      const store = receiptsStore.stores.find(s => s.name.toLowerCase() === form.value.store.toLowerCase())
      const storeId = store?.id
      
      try {
          const suggestion = await receiptsStore.getSuggestionsByBrand(brand.name, storeId)
          
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

  // Apply brand defaults
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
  
  setTimeout(() => {
    isSelecting.value = false
  }, 100)
}

const onBrandSelect = (brand: Brand) => {
  selectBrand(brand)
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
    // Handling race condition
    if (error.response?.status === 422) {
        // Just select it conceptually
        form.value.unit_of_measure = unitSearch.value
        showUnitDropdown.value = false
    } else {
        console.warn('Failed to create unit:', error)
    }
  }
}

const searchStoreNames = async (query: string) => {
    if (!query) return receiptsStore.stores.map(s => s.name)
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
    // Save current form state to local storage or similar? 
    // Ideally we'd open a modal ON TOP of this one, but user asked for redirect (or "takes user to store creation page")
    router.push({
        path: '/budget/stores',
        query: {
            new: '1',
            name: name,
            returnTo: route.fullPath
        }
    })
} 

// Bidirectional Sync Removed - Store Code here refers to Item SKU, not Store ID.

onMounted(async () => {
    // Fetch data in parallel to ensure freshness
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
})



const save = async () => {
  if (!form.value.name.trim()) return
  
  saving.value = true
  
  try {
    // Construct the ShoppingListItem payload
    // Note: ShoppingListItem only officially supports name, quantity_needed.
    // However, we want to try to capture the extra info if possible.
    // If we have a brand, we might want to append it to the name if the backend doesn't support it,
    // OR we just send what we have and hope the backend update I plan to do (or verification) handles it.
    // For now, let's construct a composite name if brand is present to ensure it's captured?
    // User asked for "GUI exactly like this", implies functionality too.
    
    // Strategy: Send the fields. If backend ignores them, so be it for now.
    // But to be safe, I'll combine Brand + Name if brand is set, to ensure it's visible.
    // Actually, widespread convention: "Brand Name".
    
    let finalName = form.value.name
    if (form.value.brand && !finalName.toLowerCase().includes(form.value.brand.toLowerCase())) {
        finalName = `${form.value.brand} ${finalName}`
    }
    if (form.value.unit_of_measure) {
         // Maybe append unit? "Milk (Gallon)"
         finalName = `${finalName} (${form.value.unit_of_measure})`
    }
    
    // WAIT: The user wants the Search Features. 
    // They probably want to create an Item that is LINKED to an inventory item if possible.
    // But here we are just adding to shopping list.
    
    const itemData: any = { // Use any temporarily to allow extra fields if backend accepts them partially
      name: finalName, // Use composite name for now to be safe
      quantity_needed: form.value.quantity,
      store: form.value.store || null,
      store_code: form.value.store_code || null,
      item_name: form.value.item_name || null,
      // We can try sending these, maybe the backend is smarter than the types suggest
      // or we will need to update the backend later.
    }

    if (isEditing.value && props.item) {
      await inventoryStore.updateShoppingItem(props.listId, props.item.id, itemData)
    } else {
      await inventoryStore.addShoppingItem(props.listId, itemData)
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
          <h2 class="text-lg font-semibold">{{ isEditing ? 'Edit Shopping Item' : 'Add Shopping Item' }}</h2>
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
               placeholder="Where to buy" 
               class="mt-1" 
               :min-chars="0"
             />
          </div>

          <!-- Brand (with autocomplete) -->
          <div>
            <label class="text-sm font-medium">Brand</label>
            <SearchableInput 
              v-model="brandSearch"
              :search-function="searchBrandsForInput"
              :display-function="(b: any) => b.name"
              :value-function="(b: any) => b.name"
              :min-chars="0"
              placeholder="Start typing brand name..." 
              class="mt-1"
              @select="onBrandSelect"
            />
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
                      :show-create-option="true"
                      :min-chars="1"
                      @select="onStoreSelect"
                      @create="handleStoreCreate"
                  />
              </div>
              <div>
                  <label class="text-xs font-medium text-muted-foreground">Store Item Name</label>
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

          <!-- Row 1: Quantity (purchases) + Quantity Unit -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm font-medium text-muted-foreground">Quantity</label>
              <Input 
                v-model.number="form.quantity" 
                type="number" 
                step="any"
                min="0" 
                placeholder="# of purchases" 
                class="mt-1" 
              />
            </div>
            <div>
              <label class="text-sm font-medium text-muted-foreground">Quantity Unit</label>
              <SearchableInput 
                v-model="form.quantity_unit"
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

          <!-- Row 2: Count (components per purchase) + Count Unit -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-sm font-medium text-muted-foreground">Count</label>
              <Input 
                v-model="form.count" 
                type="number" 
                step="any"
                min="0" 
                placeholder="# per purchase" 
                class="mt-1" 
              />
            </div>
            <div>
              <label class="text-sm font-medium text-muted-foreground">Count Unit</label>
              <SearchableInput 
                v-model="form.count_unit"
                :search-function="searchUnits"
                :display-function="(u) => u.name"
                :value-function="(u) => u.name"
                :show-create-option="true"
                :min-chars="0"
                placeholder="oz, ct, lb..." 
                class="mt-1"
              />
            </div>
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
            {{ saving ? 'Saving...' : (isEditing ? 'Save Changes' : 'Add to List') }}
          </Button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
