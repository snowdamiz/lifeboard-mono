<script setup lang="ts">
import { onMounted, computed, ref } from 'vue'
import { 
  ShoppingCart, RefreshCw, Check, Package, AlertCircle, 
  Plus, Trash2, ChevronDown, ChevronRight, Edit2, X
} from 'lucide-vue-next'
import { Button } from '@/components/ui/button'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { useInventoryStore } from '@/stores/inventory'
import type { ShoppingList, ShoppingListItem } from '@/types'

const inventoryStore = useInventoryStore()
const error = ref<string | null>(null)
const successMessage = ref<string | null>(null)

// UI state
const showCreateListModal = ref(false)
const showAddItemModal = ref(false)
const addingToListId = ref<string | null>(null)
const expandedLists = ref<Set<string>>(new Set())
const newListName = ref('')
const newItemName = ref('')
const newItemQuantity = ref(1)

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
  await inventoryStore.fetchShoppingLists()
  // Expand all lists by default
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

const createList = async () => {
  if (!newListName.value.trim()) return
  try {
    const list = await inventoryStore.createShoppingList(newListName.value)
    expandedLists.value.add(list.id)
    newListName.value = ''
    showCreateListModal.value = false
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to create list'
  }
}

const deleteList = async (listId: string) => {
  const list = inventoryStore.shoppingLists.find(l => l.id === listId)
  if (list?.is_auto_generated) {
    error.value = 'Cannot delete the auto-generated list'
    setTimeout(() => { error.value = null }, 3000)
    return
  }
  if (confirm('Delete this shopping list?')) {
    await inventoryStore.deleteShoppingList(listId)
  }
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
  <div class="space-y-6 animate-fade-in">
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
        <Button variant="outline" size="sm" @click="showCreateListModal = true">
          <Plus class="h-4 w-4 mr-1" />
          New List
        </Button>
        <Button size="sm" @click="generateList" :disabled="inventoryStore.loading">
          <RefreshCw :class="['h-4 w-4 mr-1', inventoryStore.loading && 'animate-spin']" />
          Generate
        </Button>
      </div>
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
      <h2 class="text-lg font-medium mb-2">No shopping lists yet</h2>
      <p class="text-muted-foreground text-sm mb-5">
        Create a new list or generate one from your inventory
      </p>
      <div class="flex justify-center gap-3">
        <Button variant="outline" @click="showCreateListModal = true">
          <Plus class="h-4 w-4 mr-2" />
          Create List
        </Button>
        <Button @click="generateList">
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
              </div>
              <p class="text-xs text-muted-foreground mt-0.5">
                {{ list.unpurchased_count }} of {{ list.item_count }} items remaining
              </p>
            </div>
            <div class="flex items-center gap-1">
              <Button 
                variant="ghost" 
                size="icon" 
                class="h-8 w-8"
                @click="openAddItemModal(list.id)"
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
                class="h-6 w-6 rounded flex items-center justify-center text-muted-foreground hover:text-destructive opacity-0 group-hover:opacity-100 transition-opacity"
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

    <!-- Create List Modal -->
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
          v-if="showCreateListModal"
          class="fixed inset-0 bg-background/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
          @click="showCreateListModal = false"
        >
          <div 
            class="w-full max-w-sm bg-card border border-border/80 rounded-xl shadow-2xl overflow-hidden"
            @click.stop
          >
            <div class="px-5 py-4 border-b border-border/60">
              <h2 class="text-lg font-semibold">Create Shopping List</h2>
            </div>
            <div class="p-5">
              <Input 
                v-model="newListName" 
                placeholder="List name (e.g. Groceries, Hardware Store)"
                @keyup.enter="createList"
              />
            </div>
            <div class="px-5 py-4 border-t border-border/60 flex justify-end gap-2">
              <Button variant="ghost" @click="showCreateListModal = false">Cancel</Button>
              <Button @click="createList" :disabled="!newListName.trim()">Create</Button>
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
  </div>
</template>
