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

const fetchTripReceipts = async () => {
  isLoadingReceipts.value = true
  try {
    const res = await api.listTripReceipts()
    tripReceipts.value = res.data
  } catch (err) {
    console.error('Failed to fetch trip receipts:', err)
  } finally {
    isLoadingReceipts.value = false
  }
}

const handleTransferClick = (item: InventoryItem) => {
  transferItem.value = item
  showTransferModal.value = true
}

const onTransferComplete = () => {
  // Refresh receipts to show updated quantities/items
  fetchTripReceipts()
  // Also refresh the sheet items if needed
  inventoryStore.fetchSheet(sheetId.value)
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

    <!-- Special Purchases Sheet View - Trip Receipts -->
    <template v-if="isPurchasesSheet">
      <!-- Loading state -->
      <div v-if="isLoadingReceipts" class="flex items-center justify-center py-12">
        <Loader2 class="h-8 w-8 animate-spin text-primary" />
      </div>

      <!-- Trip Receipt List -->
      <TripReceiptList 
        v-else
        :receipts="tripReceipts" 
        @transfer="handleTransferClick" 
      />
      
      <!-- Transfer Modal -->
      <ItemTransferModal
        v-model:open="showTransferModal"
        :item="transferItem"
        @transferred="onTransferComplete"
      />
    </template>

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

    <!-- Desktop Table View -->
    <Card class="hidden md:block">
      <CardContent class="p-0">
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-secondary/50">
              <tr>
                <th class="w-10 p-3">
                  <Checkbox 
                    :model-value="selectedItems.size > 0 && selectedItems.size === groupedItems.length"
                    @update:model-value="$event ? selectAll() : clearSelection()"
                  />
                </th>
                <th class="text-left p-3 text-sm font-medium text-muted-foreground w-36">Brand</th>
                <th class="text-left p-3 text-sm font-medium text-muted-foreground">Name</th>
                <th class="text-left p-3 text-sm font-medium text-muted-foreground w-32">Store</th>
                <th class="text-center p-3 text-sm font-medium text-muted-foreground w-28">Quantity</th>
                <th class="text-center p-3 text-sm font-medium text-muted-foreground w-20">Unit</th>
                <th class="text-center p-3 text-sm font-medium text-muted-foreground w-20">Min</th>
                <th class="w-20"></th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="item in groupedItems"
                :key="item.id"
                :class="[
                  'border-t border-border hover:bg-secondary/30 transition-colors',
                  item.quantity < item.min_quantity && 'bg-destructive/5'
                ]"
              >
                <td class="p-3" @click.stop>
                  <Checkbox 
                    :model-value="selectedItems.has(item.id)"
                    @update:model-value="toggleSelection(item.id)"
                  />
                </td>
                <td class="p-3 text-muted-foreground text-sm">
                  {{ item.brand || '-' }}
                </td>
                <td class="p-3">
                  <div class="flex items-center gap-2">
                    <AlertTriangle 
                      v-if="item.quantity < item.min_quantity"
                      class="h-4 w-4 text-destructive shrink-0"
                    />
                    <div class="min-w-0">
                      <span class="font-medium">{{ item.name }}</span>
                      <div v-if="item.tags?.length" class="flex gap-1 mt-1 flex-wrap">
                        <Badge
                          v-for="tag in item.tags"
                          :key="tag.id"
                          :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                          variant="outline"
                          class="text-[9px] px-1 h-4"
                        >
                          {{ tag.name }}
                        </Badge>
                      </div>
                    </div>
                  </div>
                </td>
                <td class="p-3 text-muted-foreground text-sm">
                  {{ item.store || '-' }}
                </td>
                <td class="p-3">
                  <div class="flex items-center justify-center gap-1.5">
                    <Button variant="outline" size="icon" class="h-7 w-7" @click="updateQuantity(item as unknown as GroupedInventoryItem, -1)">
                      -
                    </Button>
                    <span class="w-8 text-center font-mono text-sm">{{ item.quantity }}</span>
                    <Button variant="outline" size="icon" class="h-7 w-7" @click="updateQuantity(item as unknown as GroupedInventoryItem, 1)">
                      +
                    </Button>
                  </div>
                </td>
                <td class="p-3 text-center text-muted-foreground text-xs">
                  {{ item.unit_of_measure || '-' }}
                </td>
                <td class="p-3 text-center text-muted-foreground text-sm">
                  {{ item.min_quantity }}
                </td>
                <td class="p-3">
                  <div class="flex items-center gap-1">
                    <Button variant="ghost" size="icon" class="h-8 w-8" @click="startEdit(item)">
                      <Edit class="h-4 w-4" />
                    </Button>
                    <Button variant="ghost" size="icon" class="h-8 w-8 text-destructive hover:text-destructive" @click="deleteItem(item as unknown as GroupedInventoryItem)">
                      <Trash class="h-4 w-4" />
                    </Button>
                  </div>
                </td>
              </tr>
              <tr v-if="!groupedItems.length">
                <td colspan="8" class="p-10 text-center text-muted-foreground">
                  No items yet. Add your first item to get started.
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>

    <!-- Mobile Card View -->
    <div class="md:hidden space-y-2">
      <div
        v-for="item in groupedItems"
        :key="item.id"
        :class="[
          'bg-card rounded-xl border border-border/60 p-3 transition-colors',
          item.quantity < item.min_quantity && 'border-destructive/30 bg-destructive/5'
        ]"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <AlertTriangle 
                v-if="item.quantity < item.min_quantity"
                class="h-4 w-4 text-destructive shrink-0"
              />
              <h3 class="font-medium text-sm truncate">{{ item.name }}</h3>
              <!-- Removed Essential Badge -->
            </div>
            <div class="flex items-center gap-3 mt-1.5 text-xs text-muted-foreground flex-wrap">
              <span v-if="item.brand" class="font-medium">{{ item.brand }}</span>
              <span>Min: {{ item.min_quantity }}{{ item.unit_of_measure ? ` ${item.unit_of_measure}` : '' }}</span>
              <span v-if="item.store">{{ item.store }}</span>
            </div>
            <div v-if="item.tags?.length" class="flex gap-1 mt-1.5 flex-wrap">
              <Badge
                v-for="tag in item.tags"
                :key="tag.id"
                :style="{ backgroundColor: tag.color + '20', color: tag.color, borderColor: tag.color + '40' }"
                variant="outline"
                class="text-[9px] px-1 h-4"
              >
                {{ tag.name }}
              </Badge>
            </div>
          </div>

          <div class="flex items-center gap-1">
            <Button variant="ghost" size="icon" class="h-7 w-7" @click.stop="startEdit(item)">
              <Edit class="h-3.5 w-3.5" />
            </Button>
            <Button variant="ghost" size="icon" class="h-7 w-7 text-destructive" @click.stop="deleteItem(item as unknown as GroupedInventoryItem)">
              <Trash class="h-3.5 w-3.5" />
            </Button>
          </div>
        </div>

        <!-- Quantity Controls -->
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
      </div>

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
