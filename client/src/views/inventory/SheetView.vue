<script setup lang="ts">
import { onMounted, ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowLeft, Plus, Minus, Trash, AlertTriangle, Check, Edit, Package, X, Filter, ChevronDown } from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Checkbox } from '@/components/ui/checkbox'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent } from '@/components/ui/card'
import { useInventoryStore } from '@/stores/inventory'
import TagSelector from '@/components/shared/TagSelector.vue'
import type { InventoryItem, Tag } from '@/types'

const route = useRoute()
const router = useRouter()
const inventoryStore = useInventoryStore()
const showNewItem = ref(false)
const editingItem = ref<InventoryItem | null>(null)
const selectedItems = ref<Set<string>>(new Set())
const nameFilter = ref<Set<string>>(new Set())
const showFilterDropdown = ref(false)

const newItem = ref({
  name: '',
  quantity: 0,
  min_quantity: 0,
  is_necessity: false,
  store: '',
  unit_of_measure: '',
  brand: '',
  tags: [] as Tag[]
})

const sheetId = computed(() => route.params.id as string)

const lowItems = computed(() => 
  inventoryStore.currentSheet?.items?.filter(
    item => item.is_necessity && item.quantity < item.min_quantity
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
})

const createItem = async () => {
  if (!newItem.value.name.trim()) return
  
  await inventoryStore.createItem({
    name: newItem.value.name,
    quantity: newItem.value.quantity,
    min_quantity: newItem.value.min_quantity,
    is_necessity: newItem.value.is_necessity,
    store: newItem.value.store || null,
    unit_of_measure: newItem.value.unit_of_measure || null,
    brand: newItem.value.brand || null,
    tag_ids: newItem.value.tags.map(t => t.id),
    sheet_id: sheetId.value
  })
  
  newItem.value = { name: '', quantity: 0, min_quantity: 0, is_necessity: false, store: '', unit_of_measure: '', brand: '', tags: [] }
  showNewItem.value = false
}

const updateQuantity = async (item: InventoryItem, delta: number) => {
  const newQuantity = Math.max(0, item.quantity + delta)
  await inventoryStore.updateItem(item.id, { quantity: newQuantity })
}

const deleteItem = async (id: string) => {
  await inventoryStore.deleteItem(id)
  selectedItems.value.delete(id)
}

const toggleSelection = (id: string) => {
  const newSet = new Set(selectedItems.value)
  if (newSet.has(id)) {
    newSet.delete(id)
  } else {
    newSet.add(id)
  }
  selectedItems.value = newSet
}

const selectAll = () => {
  const allIds = inventoryStore.currentSheet?.items?.map(i => i.id) || []
  selectedItems.value = new Set(allIds)
}

const clearSelection = () => {
  selectedItems.value = new Set()
}

const bulkDelete = async () => {
  const ids = Array.from(selectedItems.value)
  for (const id of ids) {
    await inventoryStore.deleteItem(id)
  }
  selectedItems.value = new Set()
}

const startEdit = (item: InventoryItem) => {
  editingItem.value = { 
    ...item,
    tags: [...(item.tags || [])]
  }
}

const saveEdit = async () => {
  if (!editingItem.value) return
  await inventoryStore.updateItem(editingItem.value.id, {
    name: editingItem.value.name,
    quantity: editingItem.value.quantity,
    min_quantity: editingItem.value.min_quantity,
    is_necessity: editingItem.value.is_necessity,
    store: editingItem.value.store,
    unit_of_measure: editingItem.value.unit_of_measure,
    brand: editingItem.value.brand,
    tag_ids: editingItem.value.tags?.map(t => t.id) || []
  })
  editingItem.value = null
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
      <Button size="sm" class="shrink-0" @click="showNewItem = true">
        <Plus class="h-4 w-4 sm:mr-2" />
        <span class="hidden sm:inline">Add Item</span>
      </Button>
    </div>

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
                    :model-value="selectedItems.size > 0 && selectedItems.size === inventoryStore.currentSheet?.items?.length"
                    @update:model-value="$event ? selectAll() : clearSelection()"
                  />
                </th>
                <th class="text-left p-3 text-sm font-medium text-muted-foreground">Name</th>
                <th class="text-left p-3 text-sm font-medium text-muted-foreground w-28">Brand</th>
                <th class="text-center p-3 text-sm font-medium text-muted-foreground w-28">Quantity</th>
                <th class="text-center p-3 text-sm font-medium text-muted-foreground w-20">Unit</th>
                <th class="text-center p-3 text-sm font-medium text-muted-foreground w-20">Min</th>
                <th class="text-center p-3 text-sm font-medium text-muted-foreground w-20">Essential</th>
                <th class="text-left p-3 text-sm font-medium text-muted-foreground w-32">Store</th>
                <th class="w-20"></th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="item in filteredItems"
                :key="item.id"
                :class="[
                  'border-t border-border hover:bg-secondary/30 transition-colors',
                  item.is_necessity && item.quantity < item.min_quantity && 'bg-destructive/5'
                ]"
              >
                <td class="p-3" @click.stop>
                  <Checkbox 
                    :model-value="selectedItems.has(item.id)"
                    @update:model-value="toggleSelection(item.id)"
                  />
                </td>
                <td class="p-3">
                  <div class="flex items-center gap-2">
                    <AlertTriangle 
                      v-if="item.is_necessity && item.quantity < item.min_quantity"
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
                  {{ item.brand || '-' }}
                </td>
                <td class="p-3">
                  <div class="flex items-center justify-center gap-1.5">
                    <Button variant="outline" size="icon" class="h-7 w-7" @click="updateQuantity(item, -1)">
                      -
                    </Button>
                    <span class="w-8 text-center font-mono text-sm">{{ item.quantity }}</span>
                    <Button variant="outline" size="icon" class="h-7 w-7" @click="updateQuantity(item, 1)">
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
                <td class="p-3 text-center">
                  <Badge v-if="item.is_necessity" variant="default" class="px-2">
                    <Check class="h-3 w-3" />
                  </Badge>
                </td>
                <td class="p-3 text-muted-foreground text-sm">
                  {{ item.store || '-' }}
                </td>
                <td class="p-3">
                  <div class="flex items-center gap-1">
                    <Button variant="ghost" size="icon" class="h-8 w-8" @click="startEdit(item)">
                      <Edit class="h-4 w-4" />
                    </Button>
                    <Button variant="ghost" size="icon" class="h-8 w-8 text-destructive hover:text-destructive" @click="deleteItem(item.id)">
                      <Trash class="h-4 w-4" />
                    </Button>
                  </div>
                </td>
              </tr>
              <tr v-if="!inventoryStore.currentSheet?.items?.length">
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
        v-for="item in inventoryStore.currentSheet?.items"
        :key="item.id"
        :class="[
          'bg-card rounded-xl border border-border/60 p-3 transition-colors',
          item.is_necessity && item.quantity < item.min_quantity && 'border-destructive/30 bg-destructive/5'
        ]"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <AlertTriangle 
                v-if="item.is_necessity && item.quantity < item.min_quantity"
                class="h-4 w-4 text-destructive shrink-0"
              />
              <h3 class="font-medium text-sm truncate">{{ item.name }}</h3>
              <Badge v-if="item.is_necessity" variant="default" class="shrink-0 px-1.5 py-0 text-[10px]">
                Essential
              </Badge>
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
            <Button variant="ghost" size="icon" class="h-7 w-7 text-destructive" @click.stop="deleteItem(item.id)">
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
              @click="updateQuantity(item, -1)"
            >
              <Minus class="h-4 w-4" />
            </Button>
            <span :class="[
              'w-10 text-center font-mono text-lg font-semibold',
              item.is_necessity && item.quantity < item.min_quantity && 'text-destructive'
            ]">
              {{ item.quantity }}
            </span>
            <Button 
              variant="outline" 
              size="icon" 
              class="h-8 w-8 rounded-full" 
              @click="updateQuantity(item, 1)"
            >
              <Plus class="h-4 w-4" />
            </Button>
          </div>
        </div>
      </div>

      <div v-if="!inventoryStore.currentSheet?.items?.length" class="text-center py-12 text-muted-foreground">
        <Package class="h-10 w-10 mx-auto mb-3 opacity-40" />
        <p class="text-sm">No items yet</p>
        <Button size="sm" variant="outline" class="mt-3" @click="showNewItem = true">
          <Plus class="h-4 w-4 mr-1" />
          Add Item
        </Button>
      </div>
    </div>

    <!-- New Item Modal -->
    <Teleport to="body">
      <div 
        v-if="showNewItem" 
        class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4"
        @click="showNewItem = false"
      >
        <Card class="w-full sm:max-w-md shadow-xl animate-slide-up rounded-t-2xl sm:rounded-xl max-h-[90vh] overflow-auto" @click.stop>
          <CardContent class="p-4 sm:p-6">
            <h2 class="text-lg font-semibold mb-5">Add Item</h2>
            <form class="space-y-4" @submit.prevent="createItem">
              <div>
                <label class="text-sm font-medium">Name</label>
                <Input v-model="newItem.name" placeholder="Item name" class="mt-1.5" />
              </div>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="text-sm font-medium">Brand</label>
                  <Input v-model="newItem.brand" placeholder="Brand name" class="mt-1.5" />
                </div>
                <div>
                  <label class="text-sm font-medium">Unit</label>
                  <Input v-model="newItem.unit_of_measure" placeholder="e.g. lbs, oz, pcs" class="mt-1.5" />
                </div>
              </div>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="text-sm font-medium">Quantity</label>
                  <Input v-model.number="newItem.quantity" type="number" min="0" class="mt-1.5" />
                </div>
                <div>
                  <label class="text-sm font-medium">Min Qty</label>
                  <Input v-model.number="newItem.min_quantity" type="number" min="0" class="mt-1.5" />
                </div>
              </div>
              <div>
                <label class="text-sm font-medium">Store</label>
                <Input v-model="newItem.store" placeholder="Where to buy" class="mt-1.5" />
              </div>
              <div class="flex items-center gap-2">
                <Checkbox v-model="newItem.is_necessity" />
                <label class="text-sm">Mark as necessity (for shopping list)</label>
              </div>
              <div>
                <label class="text-sm font-medium">Tags</label>
                <div class="mt-1.5">
                  <TagSelector v-model="newItem.tags" placeholder="Add tags to categorize..." />
                </div>
              </div>
              <div class="flex gap-3 pt-2">
                <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="showNewItem = false">Cancel</Button>
                <Button type="submit" class="flex-1 sm:flex-none sm:ml-auto" :disabled="!newItem.name.trim()">Add Item</Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>

      <!-- Edit Item Modal -->
      <div 
        v-if="editingItem" 
        class="fixed inset-0 bg-background/80 backdrop-blur-sm z-50 flex items-end sm:items-center justify-center p-0 sm:p-4"
        @click="editingItem = null"
      >
        <Card class="w-full sm:max-w-md shadow-xl animate-slide-up rounded-t-2xl sm:rounded-xl max-h-[90vh] overflow-auto" @click.stop>
          <CardContent class="p-4 sm:p-6">
            <h2 class="text-lg font-semibold mb-5">Edit Item</h2>
            <form class="space-y-4" @submit.prevent="saveEdit">
              <div>
                <label class="text-sm font-medium">Name</label>
                <Input v-model="editingItem.name" class="mt-1.5" />
              </div>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="text-sm font-medium">Brand</label>
                  <Input :model-value="editingItem.brand ?? ''" @update:model-value="editingItem.brand = $event || null" class="mt-1.5" />
                </div>
                <div>
                  <label class="text-sm font-medium">Unit</label>
                  <Input :model-value="editingItem.unit_of_measure ?? ''" @update:model-value="editingItem.unit_of_measure = $event || null" placeholder="e.g. lbs, oz" class="mt-1.5" />
                </div>
              </div>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="text-sm font-medium">Quantity</label>
                  <Input v-model.number="editingItem.quantity" type="number" min="0" class="mt-1.5" />
                </div>
                <div>
                  <label class="text-sm font-medium">Min Qty</label>
                  <Input v-model.number="editingItem.min_quantity" type="number" min="0" class="mt-1.5" />
                </div>
              </div>
              <div>
                <label class="text-sm font-medium">Store</label>
                <Input :model-value="editingItem.store ?? ''" @update:model-value="editingItem.store = $event || null" class="mt-1.5" />
              </div>
              <div class="flex items-center gap-2">
                <Checkbox v-model="editingItem.is_necessity" />
                <label class="text-sm">Mark as necessity</label>
              </div>
              <div>
                <label class="text-sm font-medium">Tags</label>
                <div class="mt-1.5">
                  <TagSelector v-model="editingItem.tags" placeholder="Add tags..." />
                </div>
              </div>
              <div class="flex gap-3 pt-2">
                <Button variant="outline" type="button" class="flex-1 sm:flex-none" @click="editingItem = null">Cancel</Button>
                <Button type="submit" class="flex-1 sm:flex-none sm:ml-auto">Save</Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    </Teleport>
  </div>
</template>
