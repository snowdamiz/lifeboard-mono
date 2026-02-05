import { ref, computed, type Ref, type ComputedRef } from 'vue'

/**
 * Sort configuration for a specific field
 */
export interface SortField<T> {
    key: string
    label: string
    compare: (a: T, b: T) => number
}

/**
 * Options for useListSorting composable
 */
export interface UseListSortingOptions<T> {
    /** Available sort fields */
    fields: SortField<T>[]
    /** Default sort field key */
    defaultField?: string
    /** Default sort order */
    defaultOrder?: 'asc' | 'desc'
}

/**
 * Return type for useListSorting composable
 */
export interface ListSortingState<T> {
    /** Current sort field key */
    sortBy: Ref<string>
    /** Current sort order */
    sortOrder: Ref<'asc' | 'desc'>
    /** Available sort options for dropdowns */
    sortOptions: { value: string; label: string }[]
    /** Toggle sort order between asc/desc */
    toggleOrder: () => void
    /** Sort an array of items */
    sortItems: (items: T[]) => T[]
    /** Get sorted computed from a ref */
    sorted: (items: Ref<T[]> | T[]) => ComputedRef<T[]>
}

/**
 * Composable for reusable list sorting logic.
 * 
 * Provides consistent sorting behavior with configurable fields and order.
 * 
 * @example
 * ```ts
 * const { sortBy, sortOrder, sorted, toggleOrder, sortOptions } = useListSorting({
 *   fields: [
 *     { key: 'date', label: 'Sort by Date', compare: (a, b) => new Date(a.date).getTime() - new Date(b.date).getTime() },
 *     { key: 'title', label: 'Sort by Title', compare: (a, b) => a.title.localeCompare(b.title) },
 *     { key: 'progress', label: 'Sort by Progress', compare: (a, b) => a.progress - b.progress }
 *   ],
 *   defaultField: 'date',
 *   defaultOrder: 'asc'
 * })
 * 
 * const displayedItems = sorted(store.items)
 * ```
 */
export function useListSorting<T>(
    options: UseListSortingOptions<T>
): ListSortingState<T> {
    const { fields, defaultField, defaultOrder = 'asc' } = options

    const sortBy = ref(defaultField ?? fields[0]?.key ?? '')
    const sortOrder = ref<'asc' | 'desc'>(defaultOrder)

    const sortOptions = fields.map(f => ({ value: f.key, label: f.label }))

    const getCurrentField = () => fields.find(f => f.key === sortBy.value)

    const toggleOrder = () => {
        sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc'
    }

    const sortItems = (items: T[]): T[] => {
        const field = getCurrentField()
        if (!field) return items

        return [...items].sort((a, b) => {
            const comparison = field.compare(a, b)
            return sortOrder.value === 'desc' ? -comparison : comparison
        })
    }

    const sorted = (items: Ref<T[]> | T[]): ComputedRef<T[]> => {
        return computed(() => {
            const arr = 'value' in items ? items.value : items
            return sortItems(arr)
        })
    }

    return {
        sortBy,
        sortOrder,
        sortOptions,
        toggleOrder,
        sortItems,
        sorted
    }
}
