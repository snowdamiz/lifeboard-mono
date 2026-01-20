<script setup lang="ts">
import { onMounted, computed, ref, watch } from 'vue'
import { 
  ShoppingCart, RefreshCw, Check, Package, AlertCircle, 
  Plus, Trash2, ChevronDown, ChevronRight, Edit2, X, Filter,
  PlusCircle, MinusCircle, Store
} from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { useInventoryStore } from '@/stores/inventory'
import TagManager from '@/components/shared/TagManager.vue'
import type { ShoppingList, ShoppingListItem, Tag } from '@/types'
import { useTagsStore } from '@/stores/tags'

const inventoryStore = useInventoryStore()
const tagsStore = useTagsStore()
const error = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// UI state
const showListModal = ref(false)
const showAddItemModal = ref(false)
const addingToListId = ref<string | null>(null)
const expandedLists = ref<Set<string>>(new Set())
const newItemName = ref('')
const newItemQuantity = ref(1)
const isFilterOpen = ref(false)

// Edit state
const editingList = ref<ShoppingList | null>(null)
const listFormData = ref({
  name: '',
  tag_ids: [] as string[]
})
const listTagManagerRef = ref<InstanceType<typeof TagManager> | null>(null)
const listCheckedTagIds = ref<Set<string>>(new Set())

const showEditItemModal = ref(false)
const editingItem = ref<ShoppingListItem | null>(null)
const editingListId = ref<string | null>(null)
const editItemName = ref('')
const editItemQuantity = ref(1)

// Filter state
const activeFilterCount = computed(() => inventoryStore.listFilterTags.length)
const filterCheckedTagIds = ref<Set<string>>(new Set(inventoryStore.listFilterTags))
// No "applied" tags concept for filter, just selection
const filterAppliedTagIds = computed(() => new Set<string>()) 

// Watch for store filter changes (in case changed elsewhere)
watch(() => inventoryStore.listFilterTags, (newTags) => {
  filterCheckedTagIds.value = new Set(newTags)
})

const applyFilters = () => {
  inventoryStore.listFilterTags = Array.from(filterCheckedTagIds.value)
  inventoryStore.fetchShoppingLists()
  isFilterOpen.value = false
}

const clearFilters = () => {
  inventoryStore.listFilterTags = []
  filterCheckedTagIds.value = new Set()
  inventoryStore.fetchShoppingLists()
  isFilterOpen.value = false
}

const removeFilterTag = (tagId: string) => {
  inventoryStore.listFilterTags = inventoryStore.listFilterTags.filter(id => id !== tagId)
  inventoryStore.fetchShoppingLists()
}

// Toggle list expansion
const toggleList = (listId: string) => {
  if (expandedLists.value.has(listId)) {
    expandedLists.value.delete(listId)
  } else {
    expandedLists.value.add(listId)
  }
}

// Check if list is expanded
const isExpanded = (listId: string) => expandedLists.value.has(listId)

onMounted(async () => {
  inventoryStore.listFilterTags = []
  await Promise.all([
    inventoryStore.fetchShoppingLists(),
    tagsStore.fetchTags()
  ])
  // Expand all lists by default only if not filtered? Or always?
  // If filtered, we might get fewer lists, fine to expand all.
  inventoryStore.shoppingLists.forEach(l => expandedLists.value.add(l.id))
})

const generateList = async () => {
  error.value = null
  successMessage.value = null
  try {
    const result = await inventoryStore.generateShoppingList()
    if (result && result.items.length > 0) {
      successMessage.value = `Generated list with ${result.items.length} item(s)`
      expandedLists.value.add(result.id)
    } else {
      successMessage.value = 'All items are above minimum quantity. Nothing to add!'
    }
    setTimeout(() => { successMessage.value = null }, 3000)
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to generate shopping list'
    setTimeout(() => { error.value = null }, 5000)
  }
}

const openCreateListModal = () => {
  editingList.value = null
  listFormData.value = {
    name: '',
    tag_ids: []
  }
  showListModal.value = true
}

const openEditListModal = (list: ShoppingList) => {
  editingList.value = list
  listFormData.value = {
    name: list.name,
    tag_ids: list.tags?.map(t => t.id) || []
  }
  showListModal.value = true
}

const saveList = async () => {
  if (!listFormData.value.name.trim()) return
  try {
    if (editingList.value) {
      await inventoryStore.updateShoppingList(editingList.value.id, {
        name: listFormData.value.name,
        tag_ids: listFormData.value.tag_ids
      })
    } else {
      const list = await inventoryStore.createShoppingList(listFormData.value.name, undefined, listFormData.value.tag_ids)
      expandedLists.value.add(list.id)
    }
    showListModal.value = false
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to save list'
  }
}

// Add checked tags to the list form
const addCheckedTagsToList = () => {
  if (!listTagManagerRef.value) return
  const allTags = listTagManagerRef.value.allTags || []
  
  listCheckedTagIds.value.forEach(tagId => {
    if (!listFormData.value.tag_ids.includes(tagId)) {
      listFormData.value.tag_ids.push(tagId)
    }
  })
  listCheckedTagIds.value = new Set()
}

// Remove checked tags from the list form
const removeCheckedTagsFromList = () => {
  listFormData.value.tag_ids = listFormData.value.tag_ids.filter(
    id => !listCheckedTagIds.value.has(id)
  )
  listCheckedTagIds.value = new Set()
}

// Helper to get tag by ID
const getTagById = (tagId: string) => {
  return tagsStore.tags.find(t => t.id === tagId)
}

// Helper to get tag style for badges
const getTagStyle = (tagId: string) => {
  const tag = getTagById(tagId)
  if (!tag) return {}
  return { 
    backgroundColor: tag.color + '20', 
    color: tag.color, 
    borderColor: tag.color + '40' 
  }
}

// Helper to get tag color
const getTagColor = (tagId: string) => {
  const tag = getTagById(tagId)
  return tag?.color || '#64748b'
}

// Helper to get tag name
const getTagName = (tagId: string) => {
  const tag = getTagById(tagId)
  return tag?.name || 'Unknown'
}

const deleteList = async (listId: string) => {
  const list = inventoryStore.shoppingLists.find(l => l.id === listId)
  if (list?.is_auto_generated) {
    error.value = 'Cannot delete the auto-generated list'
    setTimeout(() => { error.value = null }, 3000)
    return
  }
  await inventoryStore.deleteShoppingList(listId)
}

const openAddItemModal = (listId: string) => {
  addingToListId.value = listId
  newItemName.value = ''
  newItemQuantity.value = 1
  showAddItemModal.value = true
}

const addManualItem = async () => {
  if (!newItemName.value.trim() || !addingToListId.value) return
  try {
    await inventoryStore.addShoppingItem(addingToListId.value, {
      name: newItemName.value,
      quantity_needed: newItemQuantity.value
    })
    newItemName.value = ''
    newItemQuantity.value = 1
    showAddItemModal.value = false
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to add item'
  }
}

const openEditItemModal = (listId: string, item: ShoppingListItem) => {
  editingListId.value = listId
  editingItem.value = item
  editItemName.value = item.name || item.inventory_item?.name || ''
  editItemQuantity.value = item.quantity_needed
  showEditItemModal.value = true
}

const updateItem = async () => {
  if (!editItemName.value.trim() || !editingListId.value || !editingItem.value) return
  try {
    await inventoryStore.updateShoppingItem(editingListId.value, editingItem.value.id, {
      name: editItemName.value,
      quantity_needed: editItemQuantity.value
    })
    showEditItemModal.value = false
    editingItem.value = null
    editingListId.value = null
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to update item'
  }
}

const markPurchased = async (listId: string, itemId: string) => {
  await inventoryStore.markPurchased(listId, itemId)
}

const deleteItem = async (listId: string, itemId: string) => {
  await inventoryStore.deleteShoppingItem(listId, itemId)
}

const getItemName = (item: ShoppingListItem) => {
  return item.inventory_item?.name || item.name || 'Unknown Item'
}

const totalUnpurchased = computed(() => 
  inventoryStore.shoppingLists.reduce((sum, l) => sum + l.unpurchased_count, 0)
)
</script>

<template>
  <div class="space-y-6 animate-fade-in pb-20 sm:pb-0">
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <div class="h-10 w-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <ShoppingCart class="h-5 w-5 text-primary" />
        </div>
        <div>
          <h1 class="text-xl sm:text-2xl font-semibold tracking-tight">Shopping Lists</h1>
          <p class="text-muted-foreground text-sm mt-0.5">
            {{ totalUnpurchased }} items to buy across {{ inventoryStore.shoppingLists.length }} lists
          </p>
        </div>
      </div>

      <div class="flex gap-2">
        <div class="relative">
          <Button 
            variant="outline" 
            size="sm" 
            class="h-9 relative" 
            :class="{ 'border-primary text-primary': activeFilterCount > 0 }"
            @click="isFilterOpen = !isFilterOpen"
          >
            <Filter class="h-4 w-4 sm:mr-2" />
            <span class="hidden sm:inline">Filter</span>
            <Badge 
              v-if="activeFilterCount > 0" 
              variant="secondary" 
              class="ml-2 h-5 min-w-[20px] px-1 bg-primary text-primary-foreground hover:bg-primary/90"
            >
              {{ activeFilterCount }}
            </Badge>
          </Button>

          <!-- Filter Dropdown -->
          <div 
            v-if="isFilterOpen" 
            class="absolute right-0 top-full mt-2 w-80 bg-popover text-popover-foreground border rounded-lg shadow-lg z-50 overflow-hidden"
          >
            <div class="p-3 border-b">
              <h4 class="font-medium leading-none">Filter Lists</h4>
              <p class="text-xs text-muted-foreground mt-1.5">Select tags to filter by</p>
            </div>
            <div class="p-2">
              <TagManager
                ref="filterTagManagerRef"
                v-model:checkedTagIds="filterCheckedTagIds"
                :hide-input="true"
                :compact="true"
                :embedded="true"
                :applied-tag-ids="filterAppliedTagIds"
                class="max-h-[300px] overflow-auto"
              >
                <template #actions="{ checkedCount }">
                  <Button
                    type="button"
                    size="sm"
                    class="w-full text-xs"
                    @click="applyFilters"
                  >
                    Apply Filter
                  </Button>
                </template>
              </TagManager>
            </div>

          </div>
          <!-- Backdrop -->
          <div v-if="isFilterOpen" class="fixed inset-0 z-40 bg-transparent" @click="isFilterOpen = false" />
        </div>

        <Button variant="outline" size="sm" @click="$router.push('/budget/stores')">
          <Store class="h-4 w-4 sm:mr-1" />
          <span class="hidden sm:inline">Stores</span>
        </Button>
        <Button variant="outline" size="sm" @click="openCreateListModal">
          <Plus class="h-4 w-4 mr-1" />
          New List
        </Button>
        <Button size="sm" @click="generateList" :disabled="inventoryStore.loading">
          <RefreshCw :class="['h-4 w-4 mr-1', inventoryStore.loading && 'animate-spin']" />
          Generate
        </Button>
      </div>
    </div>

    <!-- Active Filters Display -->
    <div v-if="activeFilterCount > 0" class="flex flex-wrap gap-2 items-center">
      <span class="text-xs text-muted-foreground">Active filters:</span>
      <Badge 
        v-for="tagId in inventoryStore.listFilterTags" 
        :key="tagId"
        variant="secondary"
        class="gap-1 pl-2 pr-1 py-0.5"
      >
        <span class="truncate max-w-[100px]">Tag selected</span>
        <Button 
          variant="ghost" 
          size="icon" 
          class="h-3 w-3 sm:h-4 sm:w-4 ml-1 rounded-full -mr-0.5 hover:bg-transparent hover:text-destructive"
          @click.stop="removeFilterTag(tagId)"
        >
          <X class="h-2 w-2 sm:h-3 sm:w-3" />
        </Button>
      </Badge>
      <Button variant="link" size="sm" class="h-auto p-0 text-xs text-muted-foreground" @click="clearFilters">
        Clear all
      </Button>
    </div>

    <!-- Feedback messages -->
    <div v-if="error" class="flex items-center gap-2 p-3 rounded-xl bg-destructive/10 text-destructive border border-destructive/20">
      <AlertCircle class="h-4 w-4 shrink-0" />
      <span class="text-sm">{{ error }}</span>
    </div>
    
    <div v-if="successMessage" class="flex items-center gap-2 p-3 rounded-xl bg-primary/10 text-primary border border-primary/20">
      <Check class="h-4 w-4 shrink-0" />
      <span class="text-sm">{{ successMessage }}</span>
    </div>

    <!-- Loading -->
    <div v-if="inventoryStore.loading" class="text-center py-16 text-muted-foreground">
      <div class="h-8 w-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto mb-3" />
      Loading...
    </div>

    <!-- Empty state -->
    <div v-else-if="inventoryStore.shoppingLists.length === 0" class="text-center py-16">
      <div class="h-16 w-16 rounded-2xl bg-secondary mx-auto mb-5 flex items-center justify-center">
        <ShoppingCart class="h-8 w-8 text-muted-foreground/50" />
      </div>
      <h2 class="text-lg font-medium mb-2">No shopping lists found</h2>
      <p class="text-muted-foreground text-sm mb-5">
        {{ activeFilterCount > 0 ? "Try adjusting your filters" : "Create a new list or generate one from your inventory" }}
      </p>
      <div class="flex justify-center gap-3">
        <Button variant="outline" @click="activeFilterCount > 0 ? clearFilters() : openCreateListModal()">
          <component :is="activeFilterCount > 0 ? 'X' : Plus" class="h-4 w-4 mr-2" />
          {{ activeFilterCount > 0 ? "Clear Filters" : "Create List" }}
        </Button>
        <Button @click="generateList" v-if="activeFilterCount === 0">
          <RefreshCw class="h-4 w-4 mr-2" />
          Generate from Inventory
        </Button>
      </div>
    </div>

    <!-- Shopping Lists -->
    <div v-else class="space-y-4">
      <Card v-for="list in inventoryStore.shoppingLists" :key="list.id">
        <CardHeader class="pb-3">
          <div class="flex items-center gap-3">
            <button 
              class="p-1 hover:bg-secondary rounded transition-colors"
              @click="toggleList(list.id)"
            >
              <ChevronDown v-if="isExpanded(list.id)" class="h-5 w-5 text-muted-foreground" />
              <ChevronRight v-else class="h-5 w-5 text-muted-foreground" />
            </button>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <CardTitle class="text-base">{{ list.name }}</CardTitle>
                <Badge v-if="list.is_auto_generated" variant="outline" class="text-xs">Auto</Badge>
                
                <!-- Tags Display -->
                <div v-if="list.tags && list.tags.length > 0" class="flex gap-1 ml-2">
                   <Badge 
                    v-for="tag in list.tags.slice(0, 3)" 
                    :key="tag.id" 
                    variant="secondary"
                    class="h-5 text-[10px] px-1.5 font-normal"
                    :style="{ backgroundColor: tag.color + '20', color: tag.color }"
                  >
                    {{ tag.name }}
                  </Badge>
                  <Badge v-if="list.tags.length > 3" variant="secondary" class="h-5 text-[10px] px-1.5">
                    +{{ list.tags.length - 3 }}
                  </Badge>
                </div>
              </div>
              <p class="text-xs text-muted-foreground mt-0.5">
                {{ list.unpurchased_count }} of {{ list.item_count }} items remaining
              </p>
            </div>
            <div class="flex items-center gap-1">
               <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 text-muted-foreground"
                @click.stop="openEditListModal(list)"
                title="Edit list"
              >
                <Edit2 class="h-4 w-4" />
              </Button>
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8"
                @click.stop="openAddItemModal(list.id)"
                title="Add item"
              >
                <Plus class="h-4 w-4" />
              </Button>
              <Button 
                v-if="!list.is_auto_generated"
                variant="ghost" 
                size="icon" 
                class="h-8 w-8 text-destructive"
                @click="deleteList(list.id)"
                title="Delete list"
              >
                <Trash2 class="h-4 w-4" />
              </Button>
            </div>
          </div>
        </CardHeader>
        
        <CardContent v-if="isExpanded(list.id)" class="pt-0">
          <div v-if="list.items.filter(i => !i.purchased).length === 0" class="py-6 text-center text-muted-foreground text-sm">
            All items purchased! 
            <button class="text-primary hover:underline ml-1" @click="openAddItemModal(list.id)">
              Add more items
            </button>
          </div>
          <div v-else class="space-y-1">
            <div
              v-for="item in list.items.filter(i => !i.purchased)"
              :key="item.id"
              class="flex items-center gap-3 p-2.5 rounded-lg hover:bg-secondary/70 transition-colors group"
            >
              <button
                class="h-5 w-5 rounded-md border border-border hover:border-primary hover:bg-primary/10 flex items-center justify-center transition-all"
                @click="markPurchased(list.id, item.id)"
                title="Mark as purchased"
              >
                <Check class="h-3 w-3 text-primary opacity-0 group-hover:opacity-100 transition-opacity" />
              </button>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium truncate">{{ getItemName(item) }}</p>
                <p v-if="item.inventory_item" class="text-xs text-muted-foreground">
                  {{ item.inventory_item.store || 'No store' }} • {{ item.inventory_item.sheet_name }}
                </p>
              </div>
              <span class="text-sm font-mono bg-secondary px-2 py-1 rounded-md">
                ×{{ item.quantity_needed }}
              </span>
              <button
                class="h-6 w-6 rounded flex items-center justify-center text-muted-foreground hover:text-primary sm:opacity-0 sm:group-hover:opacity-100 transition-opacity"
                @click="openEditItemModal(list.id, item)"
                title="Edit item"
              >
                <Edit2 class="h-3.5 w-3.5" />
              </button>
              <button
                class="h-6 w-6 rounded flex items-center justify-center text-muted-foreground hover:text-destructive sm:opacity-0 sm:group-hover:opacity-100 transition-opacity"
                @click="deleteItem(list.id, item.id)"
                title="Remove item"
              >
                <X class="h-3.5 w-3.5" />
              </button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Create/Edit List Modal -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div 
          v-if="showListModal"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          @click="showListModal = false"
        >
          <div 
            class="w-full max-w-lg bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">{{ editingList ? 'Edit Shopping List' : 'Create Shopping List' }}</h2>
            </div>
            <div class="p-5 space-y-4">
              <div class="space-y-2">
                <label class="text-sm font-medium">Name</label>
                <Input 
                  v-model="listFormData.name" 
                  placeholder="List name (e.g. Groceries, Hardware Store)"
                  @keyup.enter="saveList"
                />
              </div>

              <div class="space-y-2">
                <label class="text-sm font-medium">Tags</label>
                <!-- Applied Tags Display -->
                <div class="flex flex-wrap gap-1.5 mb-2" v-if="listFormData.tag_ids.length > 0">
                  <Badge
                    v-for="tagId in listFormData.tag_ids"
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
                      @click="listFormData.tag_ids = listFormData.tag_ids.filter(id => id !== tagId)"
                    >
                      <X class="h-3 w-3" />
                    </button>
                  </Badge>
                </div>
                <TagManager
                    ref="listTagManagerRef"
                    v-model:checkedTagIds="listCheckedTagIds"
                    :compact="true"
                    embedded
                    :applied-tag-ids="new Set(listFormData.tag_ids)"
                >
                  <template #actions="{ checkedCount }">
                    <div class="flex items-center gap-2 px-4 py-2 border-t border-border">
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        class="h-7 px-2 text-xs"
                        :disabled="checkedCount === 0"
                        @click="addCheckedTagsToList"
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
                        @click="removeCheckedTagsFromList"
                      >
                        <MinusCircle class="h-3 w-3 mr-1" />
                        Remove
                      </Button>
                    </div>
                  </template>
                </TagManager>
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showListModal = false">Cancel</Button>
              <Button @click="saveList" :disabled="!listFormData.name.trim()">
                {{ editingList ? 'Save Changes' : 'Create List' }}
              </Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Add Item Modal -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div 
          v-if="showAddItemModal"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          @click="showAddItemModal = false"
        >
          <div 
            class="w-full max-w-sm bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Add Item</h2>
            </div>
            <div class="p-5 space-y-4">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Item Name</label>
                <Input 
                  v-model="newItemName" 
                  placeholder="What do you need to buy?"
                />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Quantity</label>
                <Input 
                  v-model.number="newItemQuantity" 
                  type="number"
                  min="1"
                />
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showAddItemModal = false">Cancel</Button>
              <Button @click="addManualItem" :disabled="!newItemName.trim()">Add Item</Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Edit Item Modal -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition duration-150 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition duration-100 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div 
          v-if="showEditItemModal"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          @click="showEditItemModal = false"
        >
          <div 
            class="w-full max-w-sm bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Edit Item</h2>
            </div>
            <div class="p-5 space-y-4">
              <div>
                <label class="text-sm font-medium mb-1.5 block">Item Name</label>
                <Input 
                  v-model="editItemName" 
                  placeholder="Item name"
                />
              </div>
              <div>
                <label class="text-sm font-medium mb-1.5 block">Quantity</label>
                <Input 
                  v-model.number="editItemQuantity" 
                  type="number"
                  min="1"
                />
              </div>
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showEditItemModal = false">Cancel</Button>
              <Button @click="updateItem" :disabled="!editItemName.trim()">Save Changes</Button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>


