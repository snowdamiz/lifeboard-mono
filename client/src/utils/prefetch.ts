/**
 * Prefetch infrastructure for Lifeboard
 * 
 * Provides staleness guards and route-based prefetching to eliminate
 * loading spinners when navigating between views.
 * 
 * See .agent/skills/prefetch-data/SKILL.md for the full design.
 */

// --- Staleness Guard Infrastructure ---

const STALE_THRESHOLD_MS = 15_000 // 15 seconds

// Global staleness tracking — shared across all stores
const lastFetchedAt: Record<string, number> = {}
const inflightRequests: Record<string, Promise<void>> = {}

/**
 * Check if data for a given key is still fresh (fetched within threshold).
 */
export function isFresh(key: string): boolean {
    const ts = lastFetchedAt[key]
    if (!ts) return false
    return Date.now() - ts < STALE_THRESHOLD_MS
}

/**
 * Wraps a fetch function with staleness check + inflight deduplication.
 * - If data is fresh, skips the fetch entirely.
 * - If the same fetch is already in-flight, returns the existing promise (dedup).
 * - Otherwise, starts the fetch and tracks it.
 */
export async function fetchIfStale(key: string, fetchFn: () => Promise<void>): Promise<void> {
    if (isFresh(key)) return

    if (key in inflightRequests) {
        return inflightRequests[key]
    }

    const promise = fetchFn()
        .then(() => {
            lastFetchedAt[key] = Date.now()
        })
        .finally(() => {
            delete inflightRequests[key]
        })

    inflightRequests[key] = promise
    return promise
}

/**
 * Invalidate a staleness key so the next fetch will go through.
 * Call this after mutations (create/update/delete).
 */
export function invalidate(key: string): void {
    delete lastFetchedAt[key]
}

/**
 * Invalidate all keys matching a prefix.
 * e.g. invalidatePrefix('budget') clears 'budget:sources', 'budget:entries', etc.
 */
export function invalidatePrefix(prefix: string): void {
    for (const key of Object.keys(lastFetchedAt)) {
        if (key.startsWith(prefix)) {
            delete lastFetchedAt[key]
        }
    }
}


// --- Route-Based Prefetch ---

/**
 * Trigger data prefetch for a given route identifier.
 * This is fire-and-forget — callers should NOT await this.
 * The staleness guard in each store prevents double-fetching.
 */
export function prefetchForRoute(routeId: string, params?: Record<string, string>) {
    switch (routeId) {
        case 'dashboard': {
            import('@/stores/calendar').then(m => {
                const store = m.useCalendarStore()
                store.fetchTodayTasks()
            })
            import('@/stores/inventory').then(m => {
                const store = m.useInventoryStore()
                store.fetchSheets()
            })
            import('@/stores/budget').then(m => {
                const store = m.useBudgetStore()
                store.fetchSummary()
            })
            break
        }
        case 'calendar':
        case 'calendar-day': {
            import('@/stores/calendar').then(m => {
                const store = m.useCalendarStore()
                store.fetchCurrentViewTasks()
            })
            break
        }
        case 'inventory': {
            import('@/stores/inventory').then(m => {
                const store = m.useInventoryStore()
                store.fetchSheets()
            })
            break
        }
        case 'inventory-sheet': {
            if (params?.id) {
                import('@/stores/inventory').then(m => {
                    const store = m.useInventoryStore()
                    store.fetchSheet(params.id)
                })
            }
            break
        }
        case 'shopping-list': {
            import('@/stores/inventory').then(m => {
                const store = m.useInventoryStore()
                store.fetchShoppingLists()
            })
            break
        }
        case 'budget': {
            import('@/stores/budget').then(m => {
                const store = m.useBudgetStore()
                store.fetchSources()
                store.fetchMonthEntries()
                store.fetchSummary()
            })
            break
        }
        case 'budget-sources': {
            import('@/stores/budget').then(m => {
                const store = m.useBudgetStore()
                store.fetchSources()
            })
            break
        }
        case 'trips': {
            import('@/stores/receipts').then(m => {
                const store = m.useReceiptsStore()
                store.fetchTrips()
            })
            break
        }
        case 'goals': {
            import('@/stores/goals').then(m => {
                const store = m.useGoalsStore()
                store.fetchGoals()
            })
            break
        }
        case 'habits': {
            import('@/stores/habits').then(m => {
                const store = m.useHabitsStore()
                store.fetchHabits()
                store.fetchHabitInventories()
            })
            break
        }
        case 'notes': {
            import('@/stores/notes').then(m => {
                const store = m.useNotesStore()
                store.fetchNotebooks()
            })
            break
        }
        case 'tags': {
            import('@/stores/tags').then(m => {
                const store = m.useTagsStore()
                store.fetchTags()
            })
            break
        }
        case 'reports': {
            // Reports fetch their own data via composables, no store prefetch needed
            break
        }
        case 'settings': {
            import('@/stores/preferences').then(m => {
                const store = m.usePreferencesStore()
                store.fetchPreferences()
            })
            break
        }
    }
}
