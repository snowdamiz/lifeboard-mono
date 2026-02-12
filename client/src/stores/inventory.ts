import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { InventorySheet, InventoryItem, ShoppingList, ShoppingListItem } from '@/types'
import { api } from '@/services/api'
import { fetchIfStale, invalidate } from '@/utils/prefetch'

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

  const sheetFilterTags = ref<string[]>([])
  const listFilterTags = ref<string[]>([])

  // Sheet functions
  async function fetchSheets() {
    return fetchIfStale('inventory:sheets', async () => {
      loading.value = true
      try {
        const response = await api.listSheets({ tag_ids: sheetFilterTags.value.length > 0 ? sheetFilterTags.value : undefined })
        sheets.value = response.data
      } finally {
        loading.value = false
      }
    })
  }

  async function fetchSheet(id: string) {
    return fetchIfStale(`inventory:sheet:${id}`, async () => {
      loading.value = true
      try {
        const response = await api.getSheet(id)
        currentSheet.value = response.data
      } finally {
        loading.value = false
      }
    })
  }

  async function createSheet(name: string, tag_ids?: string[]) {
    const response = await api.createSheet({ name, tag_ids })
    invalidate('inventory:sheets')
    // Re-fetch to respect order and filters
    await fetchSheets()
    return response.data
  }

  async function updateSheet(id: string, updates: Partial<InventorySheet> & { tag_ids?: string[] }) {
    const response = await api.updateSheet(id, updates)
    invalidate('inventory:sheets')
    await fetchSheets()
    // Update current if selected
    if (currentSheet.value?.id === id) {
      invalidate(`inventory:sheet:${id}`)
      // Refresh current sheet to get updated tags
      await fetchSheet(id)
    }
    return response.data
  }

  async function deleteSheet(id: string) {
    await api.deleteSheet(id)
    sheets.value = sheets.value.filter(s => s.id !== id)
    invalidate('inventory:sheets')
    invalidate(`inventory:sheet:${id}`)
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
    if (item.sheet_id) invalidate(`inventory:sheet:${item.sheet_id}`)
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
    if (currentSheet.value?.id) invalidate(`inventory:sheet:${currentSheet.value.id}`)
    return response.data
  }

  async function deleteItem(id: string) {
    await api.deleteItem(id)
    if (currentSheet.value?.items) {
      currentSheet.value.items = currentSheet.value.items.filter(i => i.id !== id)
    }
    if (currentSheet.value?.id) invalidate(`inventory:sheet:${currentSheet.value.id}`)
  }

  // Shopping List functions
  async function fetchShoppingLists() {
    return fetchIfStale('inventory:shopping-lists', async () => {
      loading.value = true
      try {
        const response = await api.listShoppingLists({ tag_ids: listFilterTags.value.length > 0 ? listFilterTags.value : undefined })
        shoppingLists.value = response.data
      } finally {
        loading.value = false
      }
    })
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

  async function createShoppingList(name: string, notes?: string, tag_ids?: string[]) {
    const response = await api.createShoppingList({ name, notes, tag_ids })
    invalidate('inventory:shopping-lists')
    await fetchShoppingLists()
    return response.data
  }

  async function updateShoppingList(id: string, updates: Partial<ShoppingList> & { tag_ids?: string[] }) {
    const response = await api.updateShoppingList(id, updates)
    invalidate('inventory:shopping-lists')
    await fetchShoppingLists()
    if (currentList.value?.id === id) {
      // Refresh current list to get tags
      await fetchShoppingList(id)
    }
    return response.data
  }

  async function deleteShoppingList(id: string) {
    await api.deleteShoppingList(id)
    shoppingLists.value = shoppingLists.value.filter(l => l.id !== id)
    invalidate('inventory:shopping-lists')
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
      invalidate('inventory:shopping-lists')
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
    markPurchased,
    sheetFilterTags,
    listFilterTags
  }
})
