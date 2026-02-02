<script setup lang="ts">
import { onMounted, ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Plus, Minus, Trash, AlertTriangle, Edit, Package, X, Filter, ChevronDown, Calendar, Receipt, Loader2 } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent } from '@/components/ui/card'
import { useInventoryStore } from '@/stores/inventory'
import InventoryItemForm from '@/components/inventory/InventoryItemForm.vue'
import TripReceiptList from '@/components/inventory/TripReceiptList.vue'
import ItemTransferModal from '@/components/inventory/ItemTransferModal.vue'
import BaseItemEntry from '@/components/shared/BaseItemEntry.vue'
import type { InventoryItem, TripReceipt } from '@/types'
import { api } from '@/services/api'

interface GroupedInventoryItem extends InventoryItem {
  original_ids: string[]
}

const route = useRoute()
const router = useRouter()
const inventoryStore = useInventoryStore()
const showNewItem = ref(false)
const editingItem = ref<InventoryItem | null>(null)
const selectedItems = ref<Set<string>>(new Set())
const nameFilter = ref<Set<string>>(new Set())
const showFilterDropdown = ref(false)

// Trip receipt state
const tripReceipts = ref<TripReceipt[]>([])
const isLoadingReceipts = ref(false)
const transferItem = ref<InventoryItem | null>(null)
const showTransferModal = ref(false)
const expandedReceiptIds = ref<Set<string>>(new Set())

const sheetId = computed(() => route.params.id as string)

// Check if this is the special "Purchases" sheet
const isPurchasesSheet = computed(() => 
  inventoryStore.currentSheet?.name?.toLowerCase() === 'purchases'
)

const lowItems = computed(() => 
  inventoryStore.currentSheet?.items?.filter(
    item => item.quantity < item.min_quantity
  ) || []
)

// Get unique names for filter dropdown
const uniqueNames = computed(() => {
  const names = inventoryStore.currentSheet?.items?.map(i => i.name) || []
  return [...new Set(names)].sort()
})

// Filtered items based on name filter
const filteredItems = computed(() => {
  const items = inventoryStore.currentSheet?.items || []
  if (nameFilter.value.size === 0) return items
  return items.filter(item => nameFilter.value.has(item.name))
})

const groupedItems = computed<GroupedInventoryItem[]>(() => {
  const groups = new Map<string, GroupedInventoryItem>()
  
  filteredItems.value.forEach(item => {
    // Key by name, brand, store
    const key = `${item.name}|${item.brand || ''}|${item.store || ''}`
    
    if (groups.has(key)) {
      const group = groups.get(key)!
      group.quantity += item.quantity
      group.original_ids.push(item.id)
    } else {
      groups.set(key, {
        ...item,
        original_ids: [item.id]
      })
    }
  })
  
  return Array.from(groups.values())
})

const toggleNameFilter = (name: string) => {
  const newSet = new Set(nameFilter.value)
  if (newSet.has(name)) {
    newSet.delete(name)
  } else {
    newSet.add(name)
  }
  nameFilter.value = newSet
}

const clearNameFilter = () => {
  nameFilter.value = new Set()
}

onMounted(() => {
  inventoryStore.fetchSheet(sheetId.value)
  if (inventoryStore.currentSheet?.name?.toLowerCase() === 'purchases') {
    fetchTripReceipts()
  }
})

watch(() => isPurchasesSheet.value, (isPurchases) => {
  if (isPurchases) {
    fetchTripReceipts()
  }
})

// Refresh trip receipts when navigating to this page
watch(() => route.fullPath, () => {
  if (isPurchasesSheet.value) {
    fetchTripReceipts()
  }
})

const fetchTripReceipts = async () => {
  isLoadingReceipts.value = true
  try {
    const res = await api.listTripReceipts()
    console.log(`[DEBUG] Fetched ${res.data.length} trips. First trip has ${res.data[0]?.items?.length} items.`)
    tripReceipts.value = res.data
    // Note: No longer increment refreshKey to avoid remounting and losing expanded state
  } catch (err) {
    console.error('Failed to fetch trip receipts:', err)
  } finally {
    isLoadingReceipts.value = false
  }
}

const handleRefresh = async () => {
  await fetchTripReceipts()
  await inventoryStore.fetchSheet(sheetId.value)
}

const handleTransferClick = (item: InventoryItem) => {
  transferItem.value = item
  showTransferModal.value = true
}

const onTransferComplete = async () => {
  console.log('Transfer complete, refreshing data...')
  // Clear lists to force reactivity
  tripReceipts.value = []
  
  // Refresh receipts to show updated quantities/items
  await fetchTripReceipts()
  // Also refresh the sheet items if needed
  await inventoryStore.fetchSheet(sheetId.value)

}

const handleDeleteClick = async (item: InventoryItem) => {
  await inventoryStore.deleteItem(item.id)
  
  // Refresh views - expanded state is managed externally so it persists
  await fetchTripReceipts()
  await inventoryStore.fetchSheet(sheetId.value)
}

const handleDeleteTrip = async (tripId: string) => {
  console.log('handleDeleteTrip called with tripId:', tripId)
  
  if (!tripId) {
    console.warn('Cannot delete trip: no trip_id provided')
    return
  }
  
  try {
    console.log('Starting trip deletion...')
    const { useReceiptsStore } = await import('@/stores/receipts')
    const receiptsStore = useReceiptsStore()
    
    await receiptsStore.deleteTrip(tripId)
    console.log('Trip deleted, refreshing data...')
    
    await fetchTripReceipts()
    await inventoryStore.fetchSheet(sheetId.value)
  } catch (error) {
    console.error('Error deleting trip:', error)
  }
}

const updateQuantity = async (item: GroupedInventoryItem, delta: number) => {
  // Consolidate duplicates on update
  const newQuantity = Math.max(0, item.quantity + delta)
  
  // Update the representative item
  await inventoryStore.updateItem(item.id, { quantity: newQuantity })

  // Delete valid redundant items (so we don't have ghosts)
  // We only delete items that are NOT the current representative
  const otherIds = item.original_ids.filter(id => id !== item.id)
  
  // Create a customized promise execution to avoid race conditions or UI flicker
  if (otherIds.length > 0) {
      await Promise.all(otherIds.map(id => inventoryStore.deleteItem(id)))
      // Clean up selection if needed
      otherIds.forEach(id => selectedItems.value.delete(id))
  }
}

const deleteItem = async (item: GroupedInventoryItem) => {
  for (const id of item.original_ids) {
    await inventoryStore.deleteItem(id)
    selectedItems.value.delete(id)
  }
}

const toggleSelection = (id: string) => {
  const group = groupedItems.value.find(g => g.id === id)
  if (!group) return

  // Check if the representative is selected (proxy for the group)
  const isSelected = selectedItems.value.has(id)
  
  if (isSelected) {
     // Deselect all
     group.original_ids.forEach(oid => selectedItems.value.delete(oid))
  } else {
     // Select all
     group.original_ids.forEach(oid => selectedItems.value.add(oid))
  }
}

const selectAll = () => {
  // Select all visible items (filtered items)
  const allIds = filteredItems.value.map(i => i.id)
  selectedItems.value = new Set(allIds)
}

const clearSelection = () => {
  selectedItems.value = new Set()
}

const bulkDelete = async () => {
  const ids = Array.from(selectedItems.value)
  // Since we select ALL IDs in the group, we can just delete linearly.
  // The store handles deletion. 
  for (const id of ids) {
    await inventoryStore.deleteItem(id)
  }
  selectedItems.value = new Set()
}

const startEdit = (item: InventoryItem) => {
  editingItem.value = item
}

const onItemSaved = () => {
    // Optionally refresh sheet if needed, but store typically updates reactively
    // inventoryStore.fetchSheet(sheetId.value) 
}
</script>

<template>
  <div class="space-y-6 animate-fade-in">
    <div class="flex items-center gap-3 sm:gap-4">
      <Button variant="ghost" size="icon" class="shrink-0" @click="router.push('/inventory')">
        <ArrowLeft class="h-5 w-5" />
      </Button>
      <div class="flex-1 min-w-0">
        <h1 class="text-lg sm:text-2xl font-semibold tracking-tight truncate">{{ inventoryStore.currentSheet?.name || 'Loading...' }}</h1>
        <p class="text-muted-foreground text-xs sm:text-sm mt-0.5">
          {{ inventoryStore.currentSheet?.items?.length || 0 }} items
          <span v-if="lowItems.length > 0" class="text-destructive ml-2">
            · {{ lowItems.length }} low
          </span>
        </p>
      </div>
      <Button v-if="!isPurchasesSheet" size="sm" class="shrink-0" @click="showNewItem = true">
        <Plus class="h-4 w-4 sm:mr-2" />
        <span class="hidden sm:inline">Add Item</span>
      </Button>
    </div>

      <div v-if="isPurchasesSheet" class="space-y-4">
        <div class="flex items-center justify-between">
           <h2 class="text-lg font-semibold">Trip Receipts</h2>
           <Button variant="outline" size="sm" @click="handleRefresh" :disabled="isLoadingReceipts">
             <Loader2 v-if="isLoadingReceipts" class="h-4 w-4 mr-2 animate-spin" />
             Refresh
           </Button>
        </div>
        
        <!-- Loading state -->
        <div v-if="isLoadingReceipts" class="flex items-center justify-center py-12">
          <Loader2 class="h-8 w-8 animate-spin text-primary" />
        </div>

        <!-- TripReceiptList -->
        <TripReceiptList 
          v-else
          :receipts="tripReceipts" 
          v-model:expandedIds="expandedReceiptIds"
          @transfer="handleTransferClick" 
          @delete="handleDeleteClick"
          @deleteTrip="handleDeleteTrip"
        />
        
        <!-- Transfer Modal -->
        <ItemTransferModal
          v-model:open="showTransferModal"
          :item="transferItem"
          @transferred="onTransferComplete"
        />
      </div>

    <!-- Normal Sheet View -->
    <template v-else>
    <!-- Filter Dropdown -->
    <div class="flex items-center gap-2">
      <div class="relative">
        <Button 
          variant="outline" 
          size="sm" 
          class="h-8 gap-1.5"
          @click="showFilterDropdown = !showFilterDropdown"
        >
          <Filter class="h-3.5 w-3.5" />
          Filter by name
          <Badge v-if="nameFilter.size > 0" variant="secondary" class="ml-1 h-5 px-1.5">{{ nameFilter.size }}</Badge>
          <ChevronDown class="h-3.5 w-3.5 ml-1" />
        </Button>
        
        <div 
          v-if="showFilterDropdown"
          class="absolute left-0 top-full mt-1 w-56 origin-top-left bg-card border border-border/80 rounded-lg shadow-lg py-2 z-20 max-h-64 overflow-auto"
        >
          <div class="px-3 py-1.5 flex items-center justify-between border-b border-border/60 mb-1">
            <span class="text-xs font-medium text-muted-foreground">Filter by name</span>
            <Button v-if="nameFilter.size > 0" variant="ghost" size="sm" class="h-6 text-xs px-2" @click="clearNameFilter">
              Clear
            </Button>
          </div>
          <div 
            v-for="name in uniqueNames" 
            :key="name"
            class="flex items-center gap-2 px-3 py-1.5 hover:bg-secondary/50 cursor-pointer transition-colors"
            @click="toggleNameFilter(name)"
          >
            <Checkbox :model-value="nameFilter.has(name)" class="pointer-events-none" />
            <span class="text-sm truncate">{{ name }}</span>
          </div>
        </div>
      </div>
      
      <Button 
        v-if="nameFilter.size > 0"
        variant="ghost" 
        size="sm" 
        class="h-8 text-xs"
        @click="clearNameFilter"
      >
        <X class="h-3 w-3 mr-1" />
        Clear filter
      </Button>
    </div>

    <!-- Bulk Action Bar -->
    <div 
      v-if="selectedItems.size > 0"
      class="flex items-center justify-between gap-3 p-3 rounded-lg border border-border bg-secondary/50"
    >
      <div class="flex items-center gap-2">
        <span class="text-sm font-medium">{{ selectedItems.size }} selected</span>
        <Button variant="ghost" size="sm" class="h-7 text-xs" @click="clearSelection">
          <X class="h-3 w-3 mr-1" />
          Clear
        </Button>
      </div>
      <Button variant="destructive" size="sm" class="h-7" @click="bulkDelete">
        <Trash class="h-3.5 w-3.5 mr-1.5" />
        Delete Selected
      </Button>
    </div>

    <!-- Inventory Items - Unified Card Layout -->
    <div class="space-y-2">
      <BaseItemEntry
        v-for="item in groupedItems"
        :key="item.id"
        :name="item.name"
        :brand="item.brand"
        :store="item.store"
        :store-code="item.store_code"
        :unit="item.unit_of_measure"
        :price="item.price_per_unit"
        :total="item.total_price"
        :taxable="item.taxable ?? false"
        :tags="item.tags"
        :highlighted="item.quantity < item.min_quantity"
        highlight-class="border-destructive/30 bg-destructive/5"
      >
        <!-- Leading: Checkbox + optional warning icon -->
        <template #leading>
          <div class="flex items-center gap-2 flex-shrink-0">
            <Checkbox 
              :model-value="selectedItems.has(item.id)"
              @update:model-value="toggleSelection(item.id)"
              @click.stop
            />
            <div class="h-8 w-8 rounded-md flex items-center justify-center" :class="item.quantity < item.min_quantity ? 'bg-destructive/10' : 'bg-primary/10'">
              <AlertTriangle v-if="item.quantity < item.min_quantity" class="h-4 w-4 text-destructive" />
              <Package v-else class="h-4 w-4 text-primary" />
            </div>
          </div>
        </template>

        <!-- Right value: Min quantity info -->
        <template #right-value>
          <div class="text-sm text-muted-foreground whitespace-nowrap">
            Min: {{ item.min_quantity }}{{ item.unit_of_measure ? ` ${item.unit_of_measure}` : '' }}
          </div>
        </template>

        <!-- Extension: Quantity controls (inventory-specific) -->
        <template #extension>
          <div class="flex items-center justify-between mt-3 pt-3 border-t border-border/40">
            <span class="text-xs text-muted-foreground">Quantity</span>
            <div class="flex items-center gap-2">
              <Button 
                variant="outline" 
                size="icon" 
                class="h-8 w-8 rounded-full" 
                @click="updateQuantity(item as unknown as GroupedInventoryItem, -1)"
              >
                <Minus class="h-4 w-4" />
              </Button>
              <span :class="[
                'w-10 text-center font-mono text-lg font-semibold',
                item.quantity < item.min_quantity && 'text-destructive'
              ]">
                {{ item.quantity }}
              </span>
              <Button 
                variant="outline" 
                size="icon" 
                class="h-8 w-8 rounded-full" 
                @click="updateQuantity(item as unknown as GroupedInventoryItem, 1)"
              >
                <Plus class="h-4 w-4" />
              </Button>
            </div>
          </div>
        </template>

        <!-- Actions -->
        <template #actions>
          <div class="flex items-center gap-1 flex-shrink-0">
            <Button variant="ghost" size="icon" class="h-7 w-7" @click.stop="startEdit(item)">
              <Edit class="h-3.5 w-3.5" />
            </Button>
            <Button variant="ghost" size="icon" class="h-7 w-7 text-destructive hover:text-destructive" @click.stop="deleteItem(item as unknown as GroupedInventoryItem)">
              <Trash class="h-3.5 w-3.5" />
            </Button>
          </div>
        </template>
      </BaseItemEntry>

      <div v-if="!groupedItems.length" class="text-center py-12 text-muted-foreground">
        <Package class="h-10 w-10 mx-auto mb-3 opacity-40" />
        <p class="text-sm">No items yet</p>
        <Button size="sm" variant="outline" class="mt-3" @click="showNewItem = true">
          <Plus class="h-4 w-4 mr-1" />
          Add Item
        </Button>
      </div>
    </div>
    </template>

    <!-- New Item Modal -->
    <InventoryItemForm 
      v-if="showNewItem" 
      @close="showNewItem = false"
      @saved="onItemSaved"
    />

    <!-- Edit Item Modal -->
    <InventoryItemForm
      v-if="editingItem"
      :item="editingItem"
      @close="editingItem = null"
      @saved="onItemSaved"
    />
  </div>
</template>
