import { ref, type Ref } from 'vue'

/**
 * Generic CRUD item with ID
 */
export interface CRUDItem {
    id: string
    [key: string]: unknown
}

export interface UseCRUDStoreOptions<T extends CRUDItem> {
    /** API function to fetch items */
    fetchFn: () => Promise<{ data: T[] }>
    /** API function to create item */
    createFn: (data: Partial<T>) => Promise<{ data: T }>
    /** API function to update item */
    updateFn: (id: string, data: Partial<T>) => Promise<{ data: T }>
    /** API function to delete item */
    deleteFn: (id: string) => Promise<void>
}

export interface CRUDStoreState<T extends CRUDItem> {
    /** All items */
    items: Ref<T[]>
    /** Loading state */
    loading: Ref<boolean>
    /** Error message if any */
    error: Ref<string | null>
    /** Fetch all items */
    fetch: () => Promise<void>
    /** Create a new item */
    create: (data: Partial<T>) => Promise<T>
    /** Update an existing item */
    update: (id: string, data: Partial<T>) => Promise<T>
    /** Delete an item */
    remove: (id: string) => Promise<void>
    /** Find item by ID */
    findById: (id: string) => T | undefined
}

/**
 * Factory for creating consistent CRUD store logic.
 * 
 * Reduces boilerplate across stores by providing standard:
 * - items array with loading/error state
 * - fetch, create, update, delete methods
 * - automatic local state updates after mutations
 * 
 * @example
 * ```ts
 * import { defineStore } from 'pinia'
 * import { useCRUDStore } from '@/composables/useCRUDStore'
 * import { api } from '@/services/api'
 * 
 * export const useTasksStore = defineStore('tasks', () => {
 *   const crud = useCRUDStore({
 *     fetchFn: api.listTasks,
 *     createFn: api.createTask,
 *     updateFn: api.updateTask,
 *     deleteFn: api.deleteTask
 *   })
 *   
 *   // Add domain-specific computed/methods
 *   const completedTasks = computed(() => 
 *     crud.items.value.filter(t => t.completed)
 *   )
 *   
 *   return {
 *     ...crud,
 *     completedTasks
 *   }
 * })
 * ```
 */
export function useCRUDStore<T extends CRUDItem>(
    options: UseCRUDStoreOptions<T>
): CRUDStoreState<T> {
    const { fetchFn, createFn, updateFn, deleteFn } = options

    const items = ref<T[]>([]) as Ref<T[]>
    const loading = ref(false)
    const error = ref<string | null>(null)

    async function fetch() {
        loading.value = true
        error.value = null
        try {
            const response = await fetchFn()
            items.value = response.data
        } catch (e) {
            error.value = e instanceof Error ? e.message : 'Failed to fetch'
            throw e
        } finally {
            loading.value = false
        }
    }

    async function create(data: Partial<T>): Promise<T> {
        loading.value = true
        error.value = null
        try {
            const response = await createFn(data)
            items.value.push(response.data)
            return response.data
        } catch (e) {
            error.value = e instanceof Error ? e.message : 'Failed to create'
            throw e
        } finally {
            loading.value = false
        }
    }

    async function update(id: string, data: Partial<T>): Promise<T> {
        loading.value = true
        error.value = null
        try {
            const response = await updateFn(id, data)
            const index = items.value.findIndex(item => item.id === id)
            if (index !== -1) {
                items.value[index] = response.data
            }
            return response.data
        } catch (e) {
            error.value = e instanceof Error ? e.message : 'Failed to update'
            throw e
        } finally {
            loading.value = false
        }
    }

    async function remove(id: string): Promise<void> {
        loading.value = true
        error.value = null
        try {
            await deleteFn(id)
            items.value = items.value.filter(item => item.id !== id)
        } catch (e) {
            error.value = e instanceof Error ? e.message : 'Failed to delete'
            throw e
        } finally {
            loading.value = false
        }
    }

    function findById(id: string): T | undefined {
        return items.value.find(item => item.id === id)
    }

    return {
        items,
        loading,
        error,
        fetch,
        create,
        update,
        remove,
        findById
    }
}
