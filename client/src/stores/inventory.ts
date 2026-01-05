import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { InventorySheet, InventoryItem, ShoppingList, ShoppingListItem } from '@/types'
import { api } from '@/services/api'

export const useInventoryStore = defineStore('inventory', () => {
  const sheets = ref<InventorySheet[]>([])
  const currentSheet = ref<InventorySheet | null>(null)
  const shoppingLists = ref<ShoppingList[]>([])
  const currentList = ref<ShoppingList | null>(null)
  const loading = ref(false)

  // Computed property for backwards compatibility
  const shoppingList = computed(() => 
    shoppingLists.value.flatMap(l => l.items.filter(i => !i.purchased))
  )

  // Sheet functions
  async function fetchSheets() {
    loading.value = true
    try {
      const response = await api.listSheets()
      sheets.value = response.data
    } finally {
      loading.value = false
    }
  }

  async function fetchSheet(id: string) {
    loading.value = true
    try {
      const response = await api.getSheet(id)
      currentSheet.value = response.data
      return response.data
    } finally {
      loading.value = false
    }
  }

  async function createSheet(name: string) {
    const response = await api.createSheet({ name })
    sheets.value.push(response.data)
    return response.data
  }

  async function updateSheet(id: string, updates: Partial<InventorySheet>) {
    const response = await api.updateSheet(id, updates)
    const index = sheets.value.findIndex(s => s.id === id)
    if (index !== -1) {
      sheets.value[index] = response.data
    }
    if (currentSheet.value?.id === id) {
      currentSheet.value = { ...currentSheet.value, ...response.data }
    }
    return response.data
  }

  async function deleteSheet(id: string) {
    await api.deleteSheet(id)
    sheets.value = sheets.value.filter(s => s.id !== id)
    if (currentSheet.value?.id === id) {
      currentSheet.value = null
    }
  }

  // Item functions
  async function createItem(item: Partial<InventoryItem>) {
    const response = await api.createItem(item)
    if (currentSheet.value && currentSheet.value.id === item.sheet_id) {
      currentSheet.value.items = [...(currentSheet.value.items || []), response.data]
    }
    return response.data
  }

  async function updateItem(id: string, updates: Partial<InventoryItem>) {
    const response = await api.updateItem(id, updates)
    if (currentSheet.value?.items) {
      const index = currentSheet.value.items.findIndex(i => i.id === id)
      if (index !== -1) {
        currentSheet.value.items[index] = response.data
      }
    }
    return response.data
  }

  async function deleteItem(id: string) {
    await api.deleteItem(id)
    if (currentSheet.value?.items) {
      currentSheet.value.items = currentSheet.value.items.filter(i => i.id !== id)
    }
  }

  // Shopping List functions
  async function fetchShoppingLists() {
    loading.value = true
    try {
      const response = await api.listShoppingLists()
      shoppingLists.value = response.data
    } finally {
      loading.value = false
    }
  }

  async function fetchShoppingList(id: string) {
    loading.value = true
    try {
      const response = await api.getShoppingList(id)
      currentList.value = response.data
      // Also update in the lists array
      const index = shoppingLists.value.findIndex(l => l.id === id)
      if (index !== -1) {
        shoppingLists.value[index] = response.data
      }
      return response.data
    } finally {
      loading.value = false
    }
  }

  async function createShoppingList(name: string, notes?: string) {
    const response = await api.createShoppingList({ name, notes })
    shoppingLists.value.push(response.data)
    return response.data
  }

  async function updateShoppingList(id: string, updates: Partial<ShoppingList>) {
    const response = await api.updateShoppingList(id, updates)
    const index = shoppingLists.value.findIndex(l => l.id === id)
    if (index !== -1) {
      shoppingLists.value[index] = response.data
    }
    if (currentList.value?.id === id) {
      currentList.value = response.data
    }
    return response.data
  }

  async function deleteShoppingList(id: string) {
    await api.deleteShoppingList(id)
    shoppingLists.value = shoppingLists.value.filter(l => l.id !== id)
    if (currentList.value?.id === id) {
      currentList.value = null
    }
  }

  async function generateShoppingList() {
    loading.value = true
    try {
      const response = await api.generateShoppingList()
      // Update or add the auto-generated list
      const index = shoppingLists.value.findIndex(l => l.is_auto_generated)
      if (index !== -1) {
        shoppingLists.value[index] = response.data
      } else {
        shoppingLists.value.unshift(response.data)
      }
      return response.data
    } finally {
      loading.value = false
    }
  }

  // Shopping Item functions
  async function addShoppingItem(listId: string, item: Partial<ShoppingListItem>) {
    const response = await api.createShoppingItem(listId, item)
    const list = shoppingLists.value.find(l => l.id === listId)
    if (list) {
      list.items.push(response.data)
      list.item_count++
      list.unpurchased_count++
    }
    if (currentList.value?.id === listId) {
      currentList.value.items.push(response.data)
      currentList.value.item_count++
      currentList.value.unpurchased_count++
    }
    return response.data
  }

  async function updateShoppingItem(listId: string, itemId: string, updates: Partial<ShoppingListItem>) {
    const response = await api.updateShoppingItem(listId, itemId, updates)
    
    const updateListItems = (list: ShoppingList) => {
      const index = list.items.findIndex(i => i.id === itemId)
      if (index !== -1) {
        const wasPurchased = list.items[index].purchased
        list.items[index] = response.data
        // Update counts if purchased status changed
        if (!wasPurchased && response.data.purchased) {
          list.unpurchased_count--
        } else if (wasPurchased && !response.data.purchased) {
          list.unpurchased_count++
        }
      }
    }

    const list = shoppingLists.value.find(l => l.id === listId)
    if (list) updateListItems(list)
    if (currentList.value?.id === listId) updateListItems(currentList.value)
    
    return response.data
  }

  async function deleteShoppingItem(listId: string, itemId: string) {
    await api.deleteShoppingItem(listId, itemId)
    
    const removeFromList = (list: ShoppingList) => {
      const index = list.items.findIndex(i => i.id === itemId)
      if (index !== -1) {
        const item = list.items[index]
        list.items.splice(index, 1)
        list.item_count--
        if (!item.purchased) list.unpurchased_count--
      }
    }

    const list = shoppingLists.value.find(l => l.id === listId)
    if (list) removeFromList(list)
    if (currentList.value?.id === listId) removeFromList(currentList.value)
  }

  async function markPurchased(listId: string, itemId: string) {
    return updateShoppingItem(listId, itemId, { purchased: true })
  }

  return {
    sheets,
    currentSheet,
    shoppingLists,
    currentList,
    shoppingList,
    loading,
    fetchSheets,
    fetchSheet,
    createSheet,
    updateSheet,
    deleteSheet,
    createItem,
    updateItem,
    deleteItem,
    fetchShoppingLists,
    fetchShoppingList,
    createShoppingList,
    updateShoppingList,
    deleteShoppingList,
    generateShoppingList,
    addShoppingItem,
    updateShoppingItem,
    deleteShoppingItem,
    markPurchased
  }
})
