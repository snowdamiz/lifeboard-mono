import { ref, computed, type Ref, type ComputedRef } from 'vue'

/**
 * Tab definition
 */
export interface TabDefinition<T extends string = string> {
    key: T
    label: string
    count?: () => number
}

/**
 * Options for useTabs composable
 */
export interface UseTabsOptions<T extends string> {
    /** Available tabs */
    tabs: TabDefinition<T>[]
    /** Default active tab key */
    defaultTab?: T
    /** Persistence key for localStorage (optional) */
    persistKey?: string
}

/**
 * Return type for useTabs composable
 */
export interface TabsState<T extends string> {
    /** Current active tab key */
    activeTab: Ref<T>
    /** Tab definitions for rendering */
    tabs: TabDefinition<T>[]
    /** Check if a tab is active */
    isActive: (key: T) => boolean
    /** Set active tab */
    setTab: (key: T) => void
    /** Get label for current tab */
    activeLabel: ComputedRef<string>
}

/**
 * Composable for reusable tab state management.
 * 
 * Provides consistent tab behavior with optional persistence.
 * 
 * @example
 * ```ts
 * const { activeTab, tabs, isActive, setTab } = useTabs({
 *   tabs: [
 *     { key: 'active', label: 'Active', count: () => activeItems.value.length },
 *     { key: 'completed', label: 'Completed', count: () => completedItems.value.length }
 *   ],
 *   defaultTab: 'active',
 *   persistKey: 'goals-view-tab'
 * })
 * ```
 */
export function useTabs<T extends string>(
    options: UseTabsOptions<T>
): TabsState<T> {
    const { tabs, defaultTab, persistKey } = options

    // Load from localStorage if persistKey provided
    const getInitialTab = (): T => {
        if (persistKey) {
            try {
                const saved = localStorage.getItem(persistKey)
                if (saved && tabs.some(t => t.key === saved)) {
                    return saved as T
                }
            } catch { /* ignore */ }
        }
        return defaultTab ?? tabs[0]?.key as T
    }

    const activeTab = ref<T>(getInitialTab()) as Ref<T>

    const isActive = (key: T): boolean => activeTab.value === key

    const setTab = (key: T): void => {
        activeTab.value = key
        if (persistKey) {
            try {
                localStorage.setItem(persistKey, key)
            } catch { /* ignore */ }
        }
    }

    const activeLabel = computed(() => {
        const tab = tabs.find(t => t.key === activeTab.value)
        return tab?.label ?? ''
    })

    return {
        activeTab,
        tabs,
        isActive,
        setTab,
        activeLabel
    }
}
